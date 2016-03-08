class Service < ApplicationRecord
  DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS = 120

  belongs_to :tenant
  belongs_to :service_template               # Template this service was cloned from
  belongs_to :service                        # Parent Service
  has_many :services, :dependent => :destroy # Child services

  has_many :dialogs, -> { uniq }, :through => :service_template

  has_one :miq_request_task, :dependent => :nullify, :as => :destination
  has_one :miq_request, :through => :miq_request_task

  virtual_belongs_to :parent_service
  virtual_has_many   :direct_service_children
  virtual_has_many   :all_service_children
  virtual_has_many   :vms
  virtual_has_many   :all_vms
  virtual_column     :v_total_vms,            :type => :integer,  :uses => :vms
  virtual_has_one    :picture

  virtual_has_one    :custom_actions
  virtual_has_one    :custom_action_buttons
  virtual_has_one    :provision_dialog
  virtual_has_one    :user

  before_validation :set_tenant_from_group

  delegate :custom_actions, :custom_action_buttons, :to => :service_template, :allow_nil => true
  delegate :provision_dialog, :to => :miq_request, :allow_nil => true
  delegate :user, :to => :miq_request, :allow_nil => true

  include ServiceMixin
  include OwnershipMixin
  include CustomAttributeMixin
  include NewWithTypeStiMixin
  include ProcessTasksMixin
  include TenancyMixin

  include_concern 'RetirementManagement'
  include_concern 'Aggregation'

  virtual_column :has_parent,                               :type => :boolean

  validates_presence_of :name

  def add_resource(rsc, options = {})
    raise MiqException::Error, "Vm <#{rsc.name}> is already connected to a service." if rsc.kind_of?(Vm) && !rsc.service.nil?
    super
  end
  alias_method :<<, :add_resource

  def parent_service
    service
  end

  def has_parent?
    service_id ? true : false
  end
  alias_method :has_parent, :has_parent?

  def request_class
    ServiceReconfigureRequest
  end

  def request_type
    'service_reconfigure'
  end

  def root_service
    result = self
    until result.parent_service.nil?
      result = result.parent_service
    end
    result
  end

  def direct_service_children
    services
  end

  def indirect_service_children
    direct_service_children.collect { |s| s.direct_service_children + s.indirect_service_children }.flatten.compact
  end

  def all_service_children
    direct_service_children + indirect_service_children
  end

  def indirect_vms
    all_service_children.collect(&:direct_vms).flatten.compact
  end

  def direct_vms
    service_resources.collect { |sr| sr.resource.kind_of?(VmOrTemplate) ? sr.resource : nil }.flatten.compact
  end

  def all_vms
    direct_vms + indirect_vms
  end
  alias_method :vms, :all_vms

  def start
    raise_request_start_event
    queue_group_action(:start)
  end

  def stop
    raise_request_stop_event
    queue_group_action(:stop, last_group_index, -1)
  end

  def suspend
    queue_group_action(:suspend, last_group_index, -1)
  end

  def shutdown_guest
    queue_group_action(:shutdown_guest, last_group_index, -1)
  end

  def process_group_action(action, group_idx, direction)
    each_group_resource(group_idx) do |svc_rsc|
      begin
        rsc = svc_rsc.resource
        rsc_name =  "#{rsc.class.name}:#{rsc.id}" + (rsc.respond_to?(:name) ? ":#{rsc.name}" : "")
        if rsc.respond_to?(action)
          _log.info "Processing action <#{action}> for Service:<#{name}:#{id}>, RSC:<#{rsc_name}}> in Group Idx:<#{group_idx}>"
          rsc.send(action)
        else
          _log.info "Skipping action <#{action}> for Service:<#{name}:#{id}>, RSC:<#{rsc.class.name}:#{rsc.id}> in Group Idx:<#{group_idx}>"
        end
      rescue => err
        _log.error "Error while processing Service:<#{name}> Group Idx:<#{group_idx}>  Resource<#{rsc_name}>.  Message:<#{err}>"
      end
    end

    # Setup processing for the next group
    next_grp_idx = next_group_index(group_idx, direction)
    if next_grp_idx.nil?
      raise_final_process_event(action)
    else
      queue_group_action(action, next_grp_idx, direction, delay_for_action(next_grp_idx, action))
    end
  end

  def queue_group_action(action, group_idx = 0, direction = 1, deliver_delay = 0)
    # Verify that the VMs attached to this service have not been converted to templates
    validate_resources

    nh = {
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => "process_group_action",
      :role        => "ems_operations",
      :task_id     => "#{self.class.name.underscore}_#{id}",
      :args        => [action, group_idx, direction]
    }
    nh[:deliver_on] = deliver_delay.seconds.from_now.utc if deliver_delay > 0
    first_vm = vms.first
    nh[:zone] = first_vm.ext_management_system.zone.name unless first_vm.nil?
    MiqQueue.put(nh)
    true
  end

  def validate_resources
    # self.each_group_resource do |svc_rsc|
    #   rsc = svc_rsc.resource
    #   raise "Unsupported resource type #{rsc.class.name}" if rsc.kind_of?(VmOrTemplate) && rsc.template? == true
    # end
  end

  def picture
    st = service_template
    return nil if st.nil?
    st.picture
  end

  def validate_reconfigure
    ra = reconfigure_resource_action
    ra && ra.dialog_id && ra.fqname.present?
  end

  def reconfigure_resource_action
    service_template.resource_actions.find_by_action('Reconfigure') if service_template
  end

  def raise_final_process_event(action)
    case action.to_s
    when "start" then raise_started_event
    when "stop"  then raise_stopped_event
    end
  end

  def raise_request_start_event
    MiqEvent.raise_evm_event(self, :request_service_start)
  end

  def raise_started_event
    MiqEvent.raise_evm_event(self, :service_started)
  end

  def raise_request_stop_event
    MiqEvent.raise_evm_event(self, :request_service_stop)
  end

  def raise_stopped_event
    MiqEvent.raise_evm_event(self, :service_stopped)
  end

  def raise_provisioned_event
    MiqEvent.raise_evm_event(self, :service_provisioned)
  end

  def v_total_vms
    vms.size
  end

  def set_tenant_from_group
    self.tenant_id = miq_group.tenant_id if miq_group
  end

  def tenant_identity
    user = evm_owner
    user = User.super_admin.tap { |u| u.current_group = miq_group } if user.nil? || !user.miq_group_ids.include?(miq_group_id)
    user
  end
end
