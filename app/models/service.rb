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

  belongs_to :service_template # Template this service was cloned from
  belongs_to :tenant

  has_many :dialogs, -> { distinct }, :through => :service_template
  has_many :metric_rollups, :as => :resource
  has_many :metrics, :as => :resource
  has_many :vim_performance_states, :as => :resource

  has_one :miq_request_task, :dependent => :nullify, :as => :destination
  has_one :miq_request, :through => :miq_request_task
  has_one :picture, :through => :service_template

  virtual_belongs_to :parent_service
  virtual_has_many   :all_service_children
  virtual_has_many   :all_vms
  virtual_has_many   :direct_service_children
  virtual_has_many   :generic_objects
  virtual_has_many   :orchestration_stacks
  virtual_has_many   :power_states, :uses => :all_vms
  virtual_has_many   :vms
  virtual_has_many   :direct_vms

  virtual_has_one    :chargeback_report
  virtual_has_one    :configuration_script
  virtual_has_one    :custom_action_buttons
  virtual_has_one    :custom_actions
  virtual_has_one    :provision_dialog
  virtual_has_one    :reconfigure_dialog
  virtual_has_one    :user

  before_create :update_attributes_from_dialog

  delegate :provision_dialog, :to => :miq_request, :allow_nil => true
  delegate :user, :to => :miq_request, :allow_nil => true

  include SupportsFeatureMixin

  include CiFeatureMixin
  include CustomActionsMixin
  include CustomAttributeMixin
  include DeprecationMixin
  include ExternalUrlMixin
  include LifecycleMixin
  include Metric::CiMixin
  include NewWithTypeStiMixin
  include OwnershipMixin
  include ProcessTasksMixin
  include ServiceMixin
  include TenancyMixin

  extend InterRegionApiMethodRelay

  include_concern 'Aggregation'
  include_concern 'Operations'
  include_concern 'ResourceLinking'
  include_concern 'RetirementManagement'

  virtual_total :v_total_vms, :vms, :arel => aggregate_hardware_arel("v_total_vms", vms_tbl[:id].count, :skip_hardware => true)

  virtual_column :has_parent,   :type => :boolean
  virtual_column :power_state,  :type => :string
  virtual_column :power_status, :type => :string

  validates :name, :presence => true

  default_value_for :visible, false
  default_value_for :initiator, 'user'
  default_value_for :lifecycle_state, 'unprovisioned'
  default_value_for :retired, false

  validates :visible, :inclusion => { :in => [true, false] }
  validates :retired, :inclusion => { :in => [true, false] }

  scope :displayed, ->              { where(:visible => true) }
  scope :retired,   ->(bool = true) { where(:retired => bool) }

  supports :reconfigure do
    unsupported_reason_add(:reconfigure, _("Reconfigure unsupported")) unless validate_reconfigure
  end

  supports :retire

  alias parent_service parent
  alias_attribute :service, :parent
  virtual_belongs_to :service
  deprecate_attribute :display, :visible

  def power_states
    vms.map(&:power_state)
  end

  # renaming method from custom_actions_mixin
  alias_method :custom_service_actions, :custom_actions
  def custom_actions
    service_template ? service_template.custom_actions(self) : custom_service_actions(self)
  end

  def custom_action_buttons
    service_template ? service_template.custom_action_buttons(self) : generic_custom_buttons
  end

  def power_state
    if options[:power_status] == "starting"
      'on'  if power_states_match?(:start)
    elsif options[:power_status] == "stopping"
      'off' if power_states_match?(:stop)
    else
      return 'on' if power_states_match?(:start)
      'off' if power_states_match?(:stop)
    end
  end

  def power_status
    options[:power_status]
  end

  def service_id
    parent_id
  end
  virtual_attribute :service_id, :integer

  # has_parent? is from the ancestry mixin
  alias has_parent has_parent?

  def request_class
    ServiceReconfigureRequest
  end

  def request_type
    'service_reconfigure'
  end

  def retireable?
    return false unless provisioned?

    # top level services do not have types; this method is used only in creating tasks for child services which always have types
    # please see https://github.com/ManageIQ/manageiq/pull/17317#discussion_r186528878
    parent.present? ? true : type.present?
  end

  def allow_retire_request_creation?
    MiqRequest.with_type("ServiceRetireRequest").where(:approval_state => "pending_approval").find_each do |request|
      if request.options.try(:[], :src_ids)&.include?(id)
        next if request.request_state == "finished" || request.status == "Error"

        _log.warn("MiqRequest with id:#{request.id} to retire Service name:'#{name}' id:#{id} already created but not approved yet")
        return false
      end
    end

    true
  end

  alias root_service root
  alias services children
  alias direct_service_children children
  virtual_has_many :services

  def indirect_service_children
    descendants.where.not(children)
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

  def power_states_match?(action)
    all_states_match?(action) ? update_power_status(action) : false
  end

  def all_states_match?(action)
    if composite?
      power_states.uniq == map_power_states(action)
    else
      power_states[0] == POWER_STATE_MAP[action]
    end
  end

  # @return true if this is a composite service
  def composite?
    children.present?
  end

  # @return true if this is a single service (not made up of multiple services)
  def atomic?
    !composite?
  end

  def orchestration_stacks
    service_resources.where(:resource_type => 'OrchestrationStack').includes(:resource).collect(&:resource)
  end

  def generic_objects
    service_resources.where(:resource_type => 'GenericObject').includes(:resource).collect(&:resource)
  end

  def group_resource_actions(action_name)
    each_group_resource.collect(&action_name).uniq
  end

  def map_power_states(action)
    action_name = "#{action}_action".to_sym
    service_actions = group_resource_actions(action_name)
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
    expected_status = "#{action}_complete"
    return true if options[:power_status] == expected_status
    options[:power_status] = expected_status
    update(:options => options)
  end

  private def update_progress(hash)
    update(:options => options.merge(hash))
  end

  def process_group_action(action, group_idx, direction)
    each_group_resource(group_idx) do |svc_rsc|
      begin
        rsc = svc_rsc.resource
        rsc_action = service_action(action, svc_rsc)
        rsc_name = "#{rsc.class.name}:#{rsc.id}" + (rsc.respond_to?(:name) ? ":#{rsc.name}" : "")
        if rsc_action.nil?
          _log.info("Not Processing action for Service:<#{name}:#{id}>, RSC:<#{rsc_name}}> in Group Idx:<#{group_idx}>")
        elsif rsc.respond_to?(rsc_action)
          _log.info("Processing action <#{rsc_action}> for Service:<#{name}:#{id}>, RSC:<#{rsc_name}}> in Group Idx:<#{group_idx}>")
          rsc.send(rsc_action)
        else
          _log.info("Skipping action <#{rsc_action}> for Service:<#{name}:#{id}>, RSC:<#{rsc.class.name}:#{rsc.id}> in Group Idx:<#{group_idx}>")
        end
      rescue => err
        _log.error("Error while processing Service:<#{name}> Group Idx:<#{group_idx}>  Resource<#{rsc_name}>.  Message:<#{err}>")
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

  def my_zone
    # Verify the VM has a provider or my_zone will return the miq_server zone by default
    vms.detect(&:ext_management_system).try(:my_zone)
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

  def reconfigure_dialog
    return nil unless supports_reconfigure?
    resource_action = reconfigure_resource_action
    options = {:target => self, :reconfigure => true}

    workflow = ResourceActionWorkflow.new(self.options[:dialog], User.current_user, resource_action, options)

    DialogSerializer.new.serialize(Array[workflow.dialog], true)
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
    Service.in_my_region.each do |s|
      s.queue_chargeback_report_generation(options) unless s.vms.empty? || s.retired
    end
  end

  def chargeback_report_name
    "Chargeback-Vm-Monthly-#{name}-#{id}"
  end

  def generate_chargeback_report(options = {})
    _log.info("Generation of chargeback report for service #{name} with #{id} started...")
    MiqReportResult.where(:name => chargeback_report_name).destroy_all
    report = MiqReport.new(chargeback_yaml)
    options[:report_sync] = true
    report.queue_generate_table(options)
    _log.info("Report #{chargeback_report_name} generated")
  end

  def chargeback_yaml
    yaml = YAML.load_file(Rails.root.join('product', 'chargeback', 'chargeback_vm_monthly.yaml'))
    yaml["db_options"][:options][:service_id] = id
    yaml["title"] = chargeback_report_name
    yaml
  end

  def queue_chargeback_report_generation(options = {})
    msg = "Generating chargeback report for `#{self.class.name}` with id #{id}"
    task = MiqTask.create(
      :name    => msg,
      :state   => MiqTask::STATE_QUEUED,
      :status  => MiqTask::STATUS_OK,
      :message => "Queueing: #{msg}"
    )

    cb = {
      :class_name  => task.class.to_s,
      :instance_id => task.id,
      :method_name => :queue_callback,
      :args        => ["Finished"]
    }

    MiqQueue.submit_job(
      :service     => "reporting",
      :class_name  => self.class.name,
      :instance_id => id,
      :task_id     => task.id,
      :miq_task_id  => task.id,
      :miq_callback => cb,
      :method_name => "generate_chargeback_report",
      :args        => options
    )
    _log.info("Added to queue: #{msg}")
    task
  end

  #
  # Metric methods
  #

  PERF_ROLLUP_CHILDREN = [:vms]

  def perf_rollup_parents(interval_name = nil)
    [] unless interval_name == 'realtime'
  end

  def add_resource(rsc, options = {})
    super.tap do |service_resource|
      break if service_resource.nil?

      # Create ancestry link between services
      resource = service_resource.resource
      resource.update(:parent => self) if resource.kind_of?(Service)
    end
  end

  def enforce_single_service_parent?
    true
  end

  def add_to_service(parent_service)
    parent_service.add_resource!(self)
  end

  def remove_from_service(parent_service)
    update(:parent => nil)
    parent_service.remove_resource(self)
  end

  def configuration_script
  end

  def set_automate_timeout(timeout, action = nil)
    options[automate_timeout_key(action)] = timeout
    save!
  end

  private

  def update_attributes_from_dialog
    Service::DialogProperties.parse(options[:dialog], evm_owner).each { |key, value| self[key] = value }
  end

  def automate_timeout_key(action)
    action.nil? ? :automate_timeout : "#{action.downcase}_automate_timeout".to_sym
  end
end
