require 'ancestry'

class Service < ApplicationRecord
  DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS = 120
  DEFAULT_POWER_STATE_DELAY = 60
  DEFAULT_POWER_STATE_RETRIES = 3

  ACTION_RESPONSE = {
    "Power On"   => :start,
    "Power Off"  => :stop,
    "Shutdown"   => :shutdown_guest,
    "Suspend"    => :suspend,
    "Do Nothing" => nil
  }.freeze

  POWER_STATE_MAP = {
    :start          => "on",
    :stop           => "off",
    :suspend        => "off",
    :shutdown_guest => "off"
  }.freeze

  has_ancestry :orphan_strategy => :destroy

  belongs_to :tenant
  belongs_to :service_template               # Template this service was cloned from

  has_many :dialogs, -> { distinct }, :through => :service_template

  has_one :miq_request_task, :dependent => :nullify, :as => :destination
  has_one :miq_request, :through => :miq_request_task
  has_one :picture, :through => :service_template

  virtual_belongs_to :parent_service
  virtual_has_many   :direct_service_children
  virtual_has_many   :all_service_children
  virtual_has_many   :vms
  virtual_has_many   :all_vms
  virtual_has_many   :power_states, :uses => :all_vms
  virtual_total      :v_total_vms, :vms

  virtual_has_one    :custom_actions
  virtual_has_one    :custom_action_buttons
  virtual_has_one    :provision_dialog
  virtual_has_one    :user
  virtual_has_one    :chargeback_report

  before_validation :set_tenant_from_group

  delegate :custom_actions, :custom_action_buttons, :to => :service_template, :allow_nil => true
  delegate :provision_dialog, :to => :miq_request, :allow_nil => true
  delegate :user, :to => :miq_request, :allow_nil => true
  delegate :atomic?, :to => :service_template
  delegate :composite?, :to => :service_template

  include ServiceMixin
  include OwnershipMixin
  include CustomAttributeMixin
  include NewWithTypeStiMixin
  include ProcessTasksMixin
  include TenancyMixin
  include SupportsFeatureMixin

  include_concern 'RetirementManagement'
  include_concern 'Aggregation'

  virtual_column :has_parent,                               :type => :boolean
  virtual_column :power_state,                              :type => :string
  virtual_column :power_status,                             :type => :string

  validates_presence_of :name

  default_value_for :retired, false

  validates :retired, :inclusion => { :in => [true, false] }

  supports :reconfigure do
    unsupported_reason_add(:reconfigure, _("Reconfigure unsupported")) unless validate_reconfigure
  end

  def add_resource(rsc, options = {})
    if rsc.kind_of?(Vm) && !rsc.service.nil?
      raise MiqException::Error, _("Vm <%{name}> is already connected to a service.") % {:name => rsc.name}
    end
    super
  end

  alias parent_service parent
  alias_attribute :service, :parent
  virtual_belongs_to :service

  def power_states
    vms.map(&:power_state)
  end

  def power_state
    if options[:power_status] == "starting"
      return 'on'  if power_states_match?(:start)
    elsif options[:power_status] == "stopping"
      return 'off' if power_states_match?(:stop)
    else
      return 'on'  if power_states_match?(:start)
      return 'off' if power_states_match?(:stop)
    end
  end

  def power_status
    options[:power_status]
  end

  def service_id
    parent_id
  end
  virtual_attribute :service_id, :integer

  def has_parent?
    !root?
  end
  alias has_parent has_parent?

  def request_class
    ServiceReconfigureRequest
  end

  def request_type
    'service_reconfigure'
  end

  alias root_service root
  alias services children
  alias direct_service_children children
  virtual_has_many :services

  def indirect_service_children
    descendants.where.not(child_conditions)
  end
  Vmdb::Deprecation.deprecate_methods(self, :indirect_service_children)

  alias all_service_children descendants

  def indirect_vms
    MiqPreloader.preload_and_map(indirect_service_children, :direct_vms)
  end
  Vmdb::Deprecation.deprecate_methods(self, :indirect_vms)

  def direct_vms
    service_resources.where(:resource_type => 'VmOrTemplate').includes(:resource).collect(&:resource).compact
  end

  def all_vms
    MiqPreloader.preload_and_map(subtree, :direct_vms)
  end

  def vms
    all_vms
  end

  def last_index
    @last_index ||= last_group_index
  end

  def start
    raise_request_start_event
    queue_group_action(:start, 0, 1, delay_for_action(0, :start))
  end

  def stop
    raise_request_stop_event
    queue_group_action(:stop, last_index, -1, delay_for_action(last_index, :stop))
  end

  def suspend
    update_progress(:power_status => 'suspending')
    queue_group_action(:suspend, last_index, -1, delay_for_action(last_index, :stop))
  end

  def shutdown_guest
    queue_group_action(:shutdown_guest, last_index, -1, delay_for_action(last_index, :stop))
  end

  def calculate_power_state(action)
    if power_states_match?(action)
      status = { :power_state  => POWER_STATE_MAP[action],
                 :power_status => action.to_s + '_complete' }
      update_progress(status) { |x| modify_power_state_delay(x) }
    else
      update_progress(:increment => true) { |x| modify_power_state_delay(x) } unless timed_out?
      delay = combined_group_delay(action) + DEFAULT_POWER_STATE_DELAY
      queue_power_calculation(delay, action) unless timed_out?
      update_progress(:power_state => "timeout") { |x| modify_power_state_delay(x) } if timed_out?
    end
  end

  def timed_out?
    options[:delayed].to_i >= DEFAULT_POWER_STATE_RETRIES
  end

  def modify_power_state_delay(opts)
    cloned_options = options.dup
    case opts.keys.first
    when :reset
      cloned_options[:delayed] = nil
    when :increment
      cloned_options[:delayed] = (cloned_options[:delayed].to_i + opts[:increment])
    end
    update_attributes(:options => cloned_options)
  end

  def power_states_match?(action)
    if composite? && (power_states.uniq == map_composite_power_states(action))
      return update_power_status(action)
    elsif atomic? && (power_states[0] == POWER_STATE_MAP[action])
      return update_power_status(action)
    end
    false
  end

  def map_composite_power_states(action)
    action_name = "#{action}_action"
    service_actions = service_resources.map(&action_name.to_sym).uniq

    # We need to account for all nil :start_action or :stop_action attributes
    #   When all :start_actions are nil then return 'Power On' for the :start_action
    #   When all :stop_actions are nil then return 'Power Off' for the :stop_action
    if service_actions.compact.empty?
      action_index = Service::ACTION_RESPONSE.values.index(action)
      mod_resources = service_actions.each_with_index do |sa, i|
        sa.nil? ? service_actions[i] = Service::ACTION_RESPONSE.to_a[action_index][0] : sa
      end
    else
      mod_resources = service_actions
    end

    # Map out the final power state we should have for the passed in action
    mod_resources.map { |x| Service::ACTION_RESPONSE[x] }.map { |x| Service::POWER_STATE_MAP[x] }
  end

  def update_power_status(action)
    options[:power_status] = "#{action}_complete"
    update_attributes(:options => options)
  end

  def update_progress(hash = {})
    increment = hash.keys.include?(:increment) ? hash.delete(:increment) : nil
    hash.keys.each do |attribute|
      options[attribute] = hash[attribute]
      update_attributes(:options => options)
    end
    if block_given?
      complete = hash[:power_status] && hash[:power_status].match("_complete")
      timed_out = hash[:power_state] && hash[:power_state].match("timeout")
      yield(:reset => true) if complete || timed_out
      yield(:increment => 1) if increment
    end
  end

  def process_group_action(action, group_idx, direction)
    each_group_resource(group_idx) do |svc_rsc|
      begin
        rsc = svc_rsc.resource
        rsc_action = service_action(action, svc_rsc)
        rsc_name =  "#{rsc.class.name}:#{rsc.id}" + (rsc.respond_to?(:name) ? ":#{rsc.name}" : "")
        if rsc_action.nil?
          _log.info "Not Processing action for Service:<#{name}:#{id}>, RSC:<#{rsc_name}}> in Group Idx:<#{group_idx}>"
        elsif rsc.respond_to?(rsc_action)
          _log.info "Processing action <#{rsc_action}> for Service:<#{name}:#{id}>, RSC:<#{rsc_name}}> in Group Idx:<#{group_idx}>"
          rsc.send(rsc_action)
        else
          _log.info "Skipping action <#{rsc_action}> for Service:<#{name}:#{id}>, RSC:<#{rsc.class.name}:#{rsc.id}> in Group Idx:<#{group_idx}>"
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

  def queue_group_action(action, group_idx, direction, deliver_delay)
    nh = {
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => "process_group_action",
      :args        => [action, group_idx, direction]
    }
    nh[:deliver_on] = deliver_delay.seconds.from_now.utc if deliver_delay > 0
    nh[:zone] = my_zone if my_zone
    MiqQueue.put(nh)
    true
  end

  def queue_power_calculation(delay, action)
    return if parent_service
    calculate_power = {
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => "calculate_power_state",
      :role        => "ems_operations",
      :task_id     => "#{self.class.name.underscore}_#{id}",
      :deliver_on  => delay.seconds.from_now.utc,
      :args        => [action]
    }

    MiqQueue.put(calculate_power)
  end

  def my_zone
    first_vm = vms.first
    first_vm.ext_management_system.zone.name unless first_vm.nil?
  end

  def service_action(requested, service_resource)
    method = "#{requested}_action"
    response = service_resource.try(method)

    response.nil? ? requested : ACTION_RESPONSE[response]
  end

  def validate_reconfigure
    ra = reconfigure_resource_action
    ra && ra.dialog_id && ra.fqname.present?
  end

  def reconfigure_resource_action
    service_template.resource_actions.find_by(:action => 'Reconfigure') if service_template
  end

  def raise_final_process_event(action)
    case action.to_s
    when "start" then raise_started_event
    when "stop"  then raise_stopped_event
    end
  end

  def raise_request_start_event
    update_progress(:power_status => 'starting')
    MiqEvent.raise_evm_event(self, :request_service_start)
  end

  def raise_started_event
    MiqEvent.raise_evm_event(self, :service_started)
  end

  def raise_request_stop_event
    update_progress(:power_status => 'stopping')
    MiqEvent.raise_evm_event(self, :request_service_stop)
  end

  def raise_stopped_event
    MiqEvent.raise_evm_event(self, :service_stopped)
  end

  def raise_provisioned_event
    MiqEvent.raise_evm_event(self, :service_provisioned)
  end

  def set_tenant_from_group
    self.tenant_id = miq_group.tenant_id if miq_group
  end

  def tenant_identity
    user = evm_owner
    user = User.super_admin.tap { |u| u.current_group = miq_group } if user.nil? || !user.miq_group_ids.include?(miq_group_id)
    user
  end

  def chargeback_report
    report_result = MiqReportResult.find_by(:name => chargeback_report_name)
    if report_result.nil?
      {:results => []}
    else
      {:results => report_result.result_set}
    end
  end

  def self.queue_chargeback_reports(options = {})
    Service.all.each do |s|
      s.queue_chargeback_report_generation(options) unless s.vms.empty?
    end
  end

  def chargeback_report_name
    "Chargeback-Vm-Monthly-#{name}"
  end

  def generate_chargeback_report(options = {})
    _log.info "Generation of chargeback report for service #{name} started..."
    MiqReportResult.where(:name => chargeback_report_name).destroy_all
    report = MiqReport.new(chargeback_yaml)
    options[:report_sync] = true
    report.queue_generate_table(options)
    _log.info "Report #{chargeback_report_name} generated"
  end

  def chargeback_yaml
    yaml = YAML.load_file(File.join(Rails.root, "product/chargeback/chargeback_vm_monthly.yaml"))
    yaml["db_options"][:options][:service_id] = id
    yaml["title"] = chargeback_report_name
    yaml
  end

  def queue_chargeback_report_generation(options = {})
    MiqQueue.put(
      :role        => "reporting",
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => "generate_chargeback_report",
      :priority    => MiqQueue::NORMAL_PRIORITY,
      :args        => options
    )
    _log.info "Added to queue: generate_chargeback_report for service #{name}"
  end
end
