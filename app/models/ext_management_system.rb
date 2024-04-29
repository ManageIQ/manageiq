class ExtManagementSystem < ApplicationRecord
  include CustomActionsMixin
  include SupportsFeatureMixin
  include ExternalUrlMixin
  include VerifyCredentialsMixin
  include SupportsAttribute

  hide_attribute "aggregate_memory" # better to use total_memory (coin toss - they're similar)

  def self.with_tenant(tenant_id)
    tenant = Tenant.find(tenant_id)
    where(:tenant_id => tenant.ancestor_ids + [tenant_id])
  end

  def self.concrete_subclasses
    leaf_subclasses | descendants.select { |d| d.try(:acts_as_sti_leaf_class?) }
  end

  def self.types
    concrete_subclasses.collect(&:ems_type)
  end

  def self.permitted_types
    permitted_subclasses.collect(&:ems_type)
  end

  def self.permitted_subclasses
    concrete_subclasses.select(&:permitted?)
  end

  def self.permitted?
    Vmdb::PermissionStores.instance.supported_ems_type?(ems_type)
  end
  delegate :permitted?, :to => :class

  # when looking at supported features, only look at the classes permitted to be used
  singleton_class.send(:alias_method, :supported_subclasses, :permitted_subclasses)

  def self.api_allowed_attributes
    %w[]
  end

  def self.supported_types_for_create
    subclasses_supporting(:create)
  end

  def self.label_mapping_prefixes
    subclasses_supporting(:label_mapping).map(&:label_mapping_prefix).uniq
  end

  def self.entities_for_label_mapping
    subclasses_supporting(:label_mapping).reduce({}) { |all_mappings, klass| all_mappings.merge(klass.entities_for_label_mapping) }
  end

  def self.provider_create_params
    permitted_types_for_create.each_with_object({}) do |ems_type, create_params|
      create_params[ems_type.name] = ems_type.params_for_create if ems_type.respond_to?(:params_for_create)
    end
  end

  def self.create_from_params(params, endpoints, authentications)
    new(params).tap do |ems|
      endpoints.each { |endpoint| ems.assign_nested_endpoint(endpoint) }
      authentications.each { |authentication| ems.assign_nested_authentication(authentication) }

      ems.provider.save! if ems.provider.present? && ems.provider.changed?
      ems.save!
    end
  end

  belongs_to :provider, :autosave => true
  has_many :child_managers, :class_name => 'ExtManagementSystem', :foreign_key => 'parent_ems_id'

  belongs_to :tenant
  has_many :endpoints, :as => :resource, :dependent => :destroy, :autosave => true

  has_many :hosts, :foreign_key => "ems_id", :dependent => :nullify, :inverse_of => :ext_management_system
  has_many :non_clustered_hosts, -> { non_clustered }, :class_name => "Host", :foreign_key => "ems_id"
  has_many :clustered_hosts, -> { clustered }, :class_name => "Host", :foreign_key => "ems_id"
  has_many :vms_and_templates, :foreign_key => "ems_id", :dependent => :nullify,
           :inverse_of => :ext_management_system
  has_many :miq_templates,     :foreign_key => :ems_id, :inverse_of => :ext_management_system
  has_many :vms,               :foreign_key => :ems_id, :inverse_of => :ext_management_system
  has_many :operating_systems, :through => :vms_and_templates
  has_many :hardwares,         :through => :vms_and_templates
  has_many :networks,          :through => :hardwares
  has_many :disks,             :through => :hardwares
  has_many :physical_servers,         :foreign_key => :ems_id, :inverse_of => :ext_management_system, :dependent => :destroy
  has_many :physical_server_profiles, :foreign_key => :ems_id, :inverse_of => :ext_management_system, :dependent => :destroy
  has_many :physical_server_profile_templates, :foreign_key => :ems_id, :inverse_of => :ext_management_system, :dependent => :destroy
  has_many :placement_groups,         :foreign_key => :ems_id, :inverse_of => :ext_management_system, :dependent => :destroy

  has_many :vm_and_template_labels, :through => :vms_and_templates, :source => :labels
  # Only taggings mapped from labels, excluding user-assigned tags.
  has_many :vm_and_template_taggings, -> { joins(:tag).merge(Tag.controlled_by_mapping) }, :through => :vms_and_templates, :source => :taggings

  has_many :storages, :foreign_key => :ems_id, :dependent => :destroy, :inverse_of => :ext_management_system
  has_many :miq_alert_statuses, :foreign_key => "ems_id", :dependent => :destroy
  has_many :ems_folders,    :foreign_key => "ems_id", :dependent => :destroy, :inverse_of => :ext_management_system
  has_many :datacenters,    :foreign_key => "ems_id", :class_name => "Datacenter", :inverse_of => :ext_management_system
  has_many :ems_clusters,   :foreign_key => "ems_id", :dependent => :destroy, :inverse_of => :ext_management_system
  has_many :resource_pools, :foreign_key => "ems_id", :dependent => :destroy, :inverse_of => :ext_management_system
  has_many :customization_specs, :foreign_key => "ems_id", :dependent => :destroy, :inverse_of => :ext_management_system
  has_many :storage_profiles,    :foreign_key => "ems_id", :dependent => :destroy, :inverse_of => :ext_management_system
  has_many :storage_profile_storages, :through => :storage_profiles
  has_many :customization_scripts, :foreign_key => "manager_id", :dependent => :destroy, :inverse_of => :ext_management_system
  has_many :cloud_subnets, :foreign_key => :ems_id, :dependent => :destroy

  belongs_to :zone
  belongs_to :zone_before_pause, :class_name => "Zone", :inverse_of => :paused_ext_management_systems # used for maintenance mode

  has_many :metrics,        :as => :resource  # Destroy will be handled by purger
  has_many :metric_rollups, :as => :resource  # Destroy will be handled by purger
  has_many :vim_performance_states, :as => :resource # Destroy will be handled by purger

  has_many :miq_events, :as => :target # Destroy will be handled by purger
  has_many :ems_events, -> { order("timestamp") }, :class_name => "EmsEvent", :foreign_key => "ems_id", :inverse_of => :ext_management_system
  has_many :policy_events, -> { order("timestamp") }, :class_name => "PolicyEvent", :foreign_key => "ems_id"
  has_many :generated_events, -> { order("timestamp") }, :class_name => "EmsEvent", :foreign_key => "generating_ems_id", :inverse_of => :generating_ems
  has_many :blacklisted_events, :foreign_key => "ems_id", :dependent => :destroy, :inverse_of => :ext_management_system

  has_many :vms_and_templates_advanced_settings, :through => :vms_and_templates, :source => :advanced_settings
  has_many :service_instances, :foreign_key => :ems_id, :dependent => :destroy, :inverse_of => :ext_management_system
  has_many :service_offerings, :foreign_key => :ems_id, :dependent => :destroy, :inverse_of => :ext_management_system
  has_many :service_parameters_sets, :foreign_key => :ems_id, :dependent => :destroy, :inverse_of => :ext_management_system

  has_many :ems_licenses,   :foreign_key => :ems_id, :dependent => :destroy, :inverse_of => :ext_management_system
  has_many :ems_extensions, :foreign_key => :ems_id, :dependent => :destroy, :inverse_of => :ext_management_system

  has_many :iso_images, :through => :storages

  validates :name,     :presence => true, :uniqueness_when_changed => {:scope => [:tenant_id]}
  validates :hostname, :presence => true, :if => :hostname_required?
  validates :zone,     :presence => true

  validate :hostname_uniqueness_valid?, :hostname_format_valid?, :if => :hostname_required?
  validate :validate_ems_enabled_when_zone_changed?, :validate_zone_not_maintenance_when_ems_enabled?
  validate :validate_ems_type, :on => :create

  scope :with_eligible_manager_types, ->(eligible_types) { where(:type => Array(eligible_types).collect(&:to_s)) }
  scope :assignable, -> { where.not(:type => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager") }

  serialize :options

  supports     :refresh_ems

  def edit_with_params(params, endpoints, authentications)
    tap do |ems|
      transaction do
        # Remove endpoints/attributes that are not arriving in the arguments above
        ems.endpoints.where.not(:role => nil).where.not(:role => endpoints.map { |ep| ep['role'] }).delete_all
        ems.authentications.where.not(:authtype => nil).where.not(:authtype => authentications.map { |au| au['authtype'] }).delete_all

        ems.assign_attributes(params)
        ems.endpoints = endpoints.map(&method(:assign_nested_endpoint))
        ems.authentications = authentications.map(&method(:assign_nested_authentication))

        ems.provider.save! if ems.provider.present? && ems.provider.changed?
        ems.save!
      end
    end
  end

  def hostname_uniqueness_valid?
    return unless hostname_required?
    return unless hostname.present? # Presence is checked elsewhere

    # check uniqueness per provider type

    existing_hostnames = (self.class.all - [self]).map(&:hostname).compact.map(&:downcase)

    errors.add(:hostname, N_("has to be unique per provider type")) if existing_hostnames.include?(hostname.downcase)
  end

  def hostname_format_valid?
    return unless hostname_required?
    return unless hostname.present? # Presence is checked elsewhere
    return if hostname.ipaddress? || hostname.hostname?

    errors.add(:hostname, _("format is invalid."))
  end

  # validation - Zone cannot be changed when enabled == false
  def validate_ems_enabled_when_zone_changed?
    return if enabled_changed?

    if zone_id_changed? && !enabled?
      errors.add(:zone, N_("cannot be changed because the provider is paused"))
    end
  end

  # validation - Zone cannot be maintenance_zone when enabled == true
  def validate_zone_not_maintenance_when_ems_enabled?
    if enabled? && zone&.maintenance?
      errors.add(:zone, N_("cannot be the maintenance zone when provider is active"))
    end
  end

  include NewWithTypeStiMixin
  include UuidMixin
  include EmsRefresh::Manager
  include TenancyMixin
  include SupportsFeatureMixin
  include ComplianceMixin
  include CustomAttributeMixin

  acts_as_miq_taggable

  include FilterableMixin
  include EventMixin
  include MiqPolicyMixin
  include RelationshipMixin
  self.default_relationship_type = "ems_metadata"

  has_many :host_hardwares, :class_name => 'Hardware', :through => :hosts, :source => :hardware
  has_many :vm_hardwares, :class_name => 'Hardware', :through => :vms_and_templates, :source => :hardware
  include AggregationMixin

  include AuthenticationMixin
  include Metric::CiMixin
  include AsyncDeleteMixin

  delegate :ipaddress,
           :ipaddress=,
           :hostname,
           :hostname=,
           :port,
           :port=,
           :url,
           :url=,
           :security_protocol,
           :security_protocol=,
           :verify_ssl,
           :verify_ssl=,
           :certificate_authority,
           :certificate_authority=,
           :to => :default_endpoint,
           :allow_nil => true
  delegate :path, :path=, :to => :default_endpoint, :prefix => "endpoint", :allow_nil => true

  delegate :userid,
           :userid=,
           :password,
           :password=,
           :auth_key,
           :auth_key=,
           :to        => :default_authentication,
           :allow_nil => true,
           :prefix    => :default

  alias_method :address, :hostname # TODO: Remove all callers of address

  virtual_column :ipaddress,               :type => :string,  :uses => :endpoints
  virtual_column :hostname,                :type => :string,  :uses => :endpoints
  virtual_column :port,                    :type => :integer, :uses => :endpoints
  virtual_column :security_protocol,       :type => :string,  :uses => :endpoints

  virtual_column :emstype,                 :type => :string
  virtual_column :emstype_description,     :type => :string
  virtual_column :last_refresh_status,     :type => :string
  virtual_total  :total_vms_and_templates, :vms_and_templates
  virtual_total  :total_vms,               :vms
  virtual_total  :total_miq_templates,     :miq_templates
  virtual_total  :total_hosts,             :hosts
  virtual_total  :total_storages,          :storages
  virtual_total  :total_clusters,          :ems_clusters
  virtual_column :zone_name,               :type => :string, :uses => :zone
  virtual_column :total_vms_on,            :type => :integer
  virtual_column :total_vms_off,           :type => :integer
  virtual_column :total_vms_unknown,       :type => :integer
  virtual_column :total_vms_never,         :type => :integer
  virtual_column :total_vms_suspended,     :type => :integer
  virtual_total  :total_subnets,           :cloud_subnets

  supports_attribute :supports_auth_key_pair_create, :child_model => "AuthKeyPair"
  supports_attribute :feature => :block_storage
  supports_attribute :feature => :object_storage
  supports_attribute :feature => :cloud_tenants
  supports_attribute :feature => :volume_multiattachment
  supports_attribute :feature => :volume_resizing
  supports_attribute :supports_cloud_object_store_container_create, :child_model => "CloudObjectStoreContainer"
  supports_attribute :feature => :cinder_volume_types
  supports_attribute :feature => :cloud_subnet_create
  supports_attribute :feature => :cloud_volume
  supports_attribute :feature => :cloud_volume_create
  supports_attribute :feature => :cloud_volume_snapshots
  supports_attribute :supports_cloud_database_create, :child_model => "CloudDatabase"
  supports_attribute :supports_create_flavor, :child_model => "Flavor"
  supports_attribute :supports_create_floating_ip, :child_model => "FloatingIp"
  supports_attribute :feature => :volume_availability_zones
  supports_attribute :supports_create_security_group, :child_model => "SecurityGroup"
  supports_attribute :supports_create_host_aggregate, :child_model => "HostAggregate"
  supports_attribute :feature => :create_network_router
  supports_attribute :feature => :create_iso_datastore
  supports_attribute :feature => :storage_services
  supports_attribute :feature => :storage_service_create
  supports_attribute :feature => :add_storage
  supports_attribute :feature => :add_host_initiator
  supports_attribute :supports_create_host_initiator_group, :child_model => "HostInitiatorGroup"
  supports_attribute :feature => :add_volume_mapping

  virtual_sum :total_vcpus,        :hosts, :total_vcpus
  virtual_sum :total_memory,       :hosts, :ram_size
  virtual_sum :total_cloud_vcpus,  :vms,   :cpu_total_cores
  virtual_sum :total_cloud_memory, :vms,   :ram_size

  alias_method :clusters, :ems_clusters # Used by web-services to return clusters as the property name
  alias_attribute :to_s, :name

  default_value_for :enabled, true

  # Move ems to maintenance zone and backup current one
  # @param orig_zone [Integer] because of zone of child manager can be changed by parent manager's ensure_managers() callback
  #                            we need to specify original zone for children explicitly
  def pause!(orig_zone = nil)
    previous_zone = orig_zone || zone
    if previous_zone.maintenance?
      _log.warn("Trying to pause paused EMS [#{name}] id [#{id}]. Skipping.")
      return
    end

    _log.info("Pausing EMS [#{name}] id [#{id}].")

    transaction do
      all_managers = [self] + child_managers
      all_managers.each do |ems|
        ems.update!(
          :zone_before_pause => previous_zone,
          :zone              => Zone.maintenance_zone,
          :enabled           => false
        )
      end
    end
    _log.info("Pausing EMS [#{name}] id [#{id}] successful.")
  end

  def pause_queue!(priority: MiqQueue::NORMAL_PRIORITY)
    MiqQueue.put(
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => "pause!",
      :priority    => priority,
      :zone        => my_zone
    )
  end

  # Move ems to original zone, reschedule task/jobs/.. collected during maintenance
  def resume!
    _log.info("Resuming EMS [#{name}] id [#{id}].")

    new_zone = if zone_before_pause.nil?
                 zone.maintenance? ? Zone.default_zone : zone
               else
                 zone_before_pause
               end

    transaction do
      all_managers = [self] + child_managers
      all_managers.each do |ems|
        ems.update!(
          :zone_before_pause => nil,
          :zone              => new_zone,
          :enabled           => true
        )
      end
    end

    _log.info("Resuming EMS [#{name}] id [#{id}] successful.")
  end

  def self.with_ipaddress(ipaddress)
    joins(:endpoints).where(:endpoints => {:ipaddress => ipaddress})
  end

  def self.with_hostname(hostname)
    joins(:endpoints).where(:endpoints => {:hostname => hostname})
  end

  def self.with_role(role)
    joins(:endpoints).where(:endpoints => {:role => role})
  end

  def self.with_port(port)
    joins(:endpoints).where(:endpoints => {:port => port})
  end

  def self.raw_connect?(*params)
    !!raw_connect(*params)
  end

  # Interface method that should be defined within the EMS of the provider.
  #
  def self.raw_connect(*_args)
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def self.model_name_from_emstype(emstype)
    model_from_emstype(emstype).try(:name)
  end

  def self.model_from_emstype(emstype)
    emstype = emstype.downcase
    ExtManagementSystem.concrete_subclasses.detect { |k| k.ems_type == emstype }
  end

  def self.short_token
    if self == ManageIQ::Providers::BaseManager
      nil
    elsif module_parent == ManageIQ::Providers
      # "Infra"
      name.demodulize.sub(/Manager$/, '')
    elsif module_parent != Object
      # "Vmware"
      module_parent.name.demodulize
    end
  end

  def self.short_name
    if (t = short_token)
      "Ems#{t}"
    else
      name
    end
  end

  def self.base_manager
    (ancestors.select { |klass| klass < ::ExtManagementSystem } - [::ManageIQ::Providers::BaseManager]).last
  end

  def self.db_name
    base_manager.short_name
  end

  def self.provision_class(_via)
    self::Provision
  end

  def self.provision_workflow_class
    self::ProvisionWorkflow
  end

  BELONGS_TO_DESCENDANTS_CLASSES_BY_NAME = {
    'Network Manager' => 'ManageIQ::Providers::NetworkManager'
  }.freeze

  def self.belongsto_descendant_class(name)
    return unless (descendant = BELONGS_TO_DESCENDANTS_CLASSES_BY_NAME.keys.detect { |x| name.end_with?(x) })

    BELONGS_TO_DESCENDANTS_CLASSES_BY_NAME[descendant]
  end

  def supported_auth_types
    %w[default]
  end

  def supports_authentication?(authtype)
    supported_auth_types.include?(authtype.to_s)
  end

  # UI method for determining which icon to show for a particular EMS
  def image_name
    emstype.downcase
  end

  def default_authentication
    authentication_type(default_authentication_type) || authentications.build(:authtype => default_authentication_type)
  end

  def default_endpoint
    default = endpoints.detect { |e| e.role == "default" }
    default || endpoints.build(:role => "default")
  end

  # Takes multiple connection data
  # endpoints, and authentications
  def connection_configurations=(options)
    options.each do |option|
      add_connection_configuration_by_role(option)
    end

    delete_unused_connection_configurations(options)
  end

  def delete_unused_connection_configurations(options)
    chosen_endpoints = options.map { |x| x.deep_symbolize_keys.fetch_path(:endpoint, :role).try(:to_sym) }.compact.uniq
    existing_endpoints = endpoints.pluck(:role).map(&:to_sym)
    # Delete endpoint that were not picked
    roles_for_deletion = existing_endpoints - chosen_endpoints
    endpoints.select { |x| x.role && roles_for_deletion.include?(x.role.to_sym) }.each(&:mark_for_destruction)
    authentications.select { |x| x.authtype && roles_for_deletion.include?(x.authtype.to_sym) }.each(&:mark_for_destruction)
  end

  def connection_configurations
    roles = endpoints.map(&:role)
    options = {}

    roles.each do |role|
      conn = connection_configuration_by_role(role)
      options[role] = conn
    end

    connections = OpenStruct.new(options)
    connections.roles = roles
    connections
  end

  # Takes a hash of connection data
  # hostname, port, and authentication
  # if no role is passed in assume is default role
  def add_connection_configuration_by_role(connection)
    connection.deep_symbolize_keys!
    unless connection[:endpoint].key?(:role)
      connection[:endpoint][:role] ||= "default"
    end
    if connection[:authentication].blank?
      connection.delete(:authentication)
    else
      unless connection[:authentication].key?(:role)
        endpoint_role = connection[:endpoint][:role]
        authentication_role = endpoint_role == "default" ? default_authentication_type.to_s : endpoint_role
        connection[:authentication][:role] ||= authentication_role
      end
    end

    build_connection(connection)
  end

  def connection_configuration_by_role(role = "default")
    endpoint = endpoints.detect { |e| e.role == role }

    if endpoint
      authtype = endpoint.role == "default" ? default_authentication_type.to_s : endpoint.role
      auth = authentications.detect { |a| a.authtype == authtype }

      options = {:endpoint => endpoint, :authentication => auth}
      OpenStruct.new(options)
    end
  end

  def hostnames
    hostnames ||= endpoints.map(&:hostname)
    hostnames
  end

  def authentication_check_role
    'ems_operations'
  end

  def self.hostname_required?
    true
  end
  delegate :hostname_required?, :to => :class

  def my_zone
    zone.try(:name).presence || MiqServer.my_zone
  end
  alias_method :zone_name, :my_zone

  def emstype_description
    self.class.description || emstype.titleize
  end

  def with_provider_connection(options = {})
    raise _("no block given") unless block_given?

    _log.info("Connecting through #{self.class.name}: [#{name}]")
    connection = connect(options)
    yield connection
  ensure
    disconnect(connection) if connection
  end

  def disconnect(_connection)
  end

  def self.refresh_all_ems_timer
    ems_ids = where(:zone_id => MiqServer.my_server.zone.id).pluck(:id)
    refresh_ems(ems_ids, true) unless ems_ids.empty?
  end

  def self.refresh_ems(ems_ids, _reload = false)
    ems_ids = [ems_ids] unless ems_ids.kind_of?(Array)
    ems_ids = ems_ids.collect { |id| [ExtManagementSystem, id] }
    EmsRefresh.queue_refresh(ems_ids)
  end

  def last_refresh_status
    if last_refresh_date
      last_refresh_error ? "error" : "success"
    else
      "never"
    end
  end

  # Queue an EMS refresh using +opts+. Credentials must exist, and the
  # authentication status must be ok, otherwise an error is raised.
  #
  def refresh_ems(opts = {})
    if missing_credentials?
      raise _("no Provider credentials defined")
    end
    unless authentication_status_ok?
      raise _("Provider failed last authentication check")
    end

    EmsRefresh.queue_refresh(self, nil, opts)
  end

  alias queue_refresh refresh_ems

  # Execute an EMS refresh immediately. Credentials must exist, and the
  # authentication status must be ok, otherwise an error is raised.
  #
  def refresh
    raise _("no Provider credentials defined") if missing_credentials?
    raise _("Provider failed last authentication check") unless authentication_status_ok?

    EmsRefresh.refresh(self)
  end

  def self.ems_infra_discovery_types
    @ems_infra_discovery_types ||= %w[virtualcenter rhevm openstack_infra]
  end

  def self.ems_physical_infra_discovery_types
    @ems_physical_infra_discovery_types ||= %w[lenovo_ph_infra]
  end

  # override destroy_queue from AsyncDeleteMixin
  def self.destroy_queue(ids)
    find(Array.wrap(ids)).map(&:destroy_queue)
  end

  def destroy_queue(queue_options = {})
    msg = "Queuing destroy of #{self.class.name} with id: #{id}"

    _log.info(msg)

    # Before we queue the `#destroy` pause the provider to prevent a provider in
    # a bad state from filling up the queue preventing the `#destroy` from being
    # processed.
    pause_queue!(:priority => MiqQueue::HIGH_PRIORITY)

    task = MiqTask.create(
      :name    => "Destroying #{self.class.name} with id: #{id}",
      :state   => MiqTask::STATE_QUEUED,
      :status  => MiqTask::STATUS_OK,
      :message => msg
    )

    orchestrate_destroy_queue(task.id, queue_options)

    task.id
  end

  def ems_workers
    MiqWorker.find_alive.where(:queue_name => queue_name)
  end

  def wait_for_ems_workers_removal
    return if Rails.env.test?

    quiesce_loop_timeout = ::Settings.server.worker_monitor.quiesce_loop_timeout || 5.minutes
    worker_monitor_poll  = (::Settings.server.worker_monitor.poll || 1.second).to_i_with_method
    kill_ems_workers_started_on = Time.now.utc

    loop do
      # killed workers will have their row removed, so we wait for this
      break unless ems_workers.exists?
      break if (Time.now.utc - kill_ems_workers_started_on) > quiesce_loop_timeout

      sleep worker_monitor_poll
    end
  end

  def orchestrate_destroy_queue(task_id, queue_options = {})
    self.class._queue_task('orchestrate_destroy', [id], task_id, queue_options.reverse_merge(:msg_timeout => 3_600))
  end

  def orchestrate_destroy(task_id = nil)
    # If the provider hasn't been disabled yet by the high-priority pause! queue method
    # requeue the destroy operation to be run later.
    return orchestrate_destroy_queue(task_id, :deliver_on => 1.minute.from_now.utc) if enabled?

    # Async kill each ems worker and wait until their row is removed before we delete
    # the ems/managers to ensure a worker doesn't recreate the ems/manager.
    ems_workers.each(&:kill_async)
    wait_for_ems_workers_removal

    _log.info("Destroying #{child_managers.count} child_managers")
    child_managers.each(&:orchestrate_destroy)

    destroy

    return if task_id.blank?

    msg = "#{self.class.name} with id: #{id} destroyed"
    MiqTask.update_status(task_id, MiqTask::STATE_FINISHED, MiqTask::STATUS_OK, msg)
    _log.info(msg)
  end

  def disconnect_inv
    hosts.each { |h| h.disconnect_ems(self) }
    vms.each   { |v| v.disconnect_ems(self) }

    ems_folders.destroy_all
    ems_clusters.destroy_all
    resource_pools.destroy_all
  end

  def queue_name
    "ems_#{id}"
  end

  # Until all providers have an operations worker we can continue
  # to use the GenericWorker to run ems_operations roles.
  #
  def queue_name_for_ems_operations
    'generic'
  end

  def queue_name_for_ems_refresh
    queue_name
  end

  def enforce_policy(target, event)
    inputs = {:ext_management_system => self}
    inputs[:vm]   = target if target.kind_of?(Vm)
    inputs[:host] = target if target.kind_of?(Host)
    MiqEvent.raise_evm_event(target, event, inputs)
  end

  alias_method :all_storages,           :storages
  alias_method :datastores,             :storages # Used by web-services to return datastores as the property name

  #
  # Relationship methods
  #

  # Folder relationship methods
  def ems_folder_root
    folders.first
  end

  def folders
    children(:of_type => 'EmsFolder').sort_by { |c| c.name.downcase }
  end

  alias_method :add_folder,    :set_child
  alias_method :remove_folder, :remove_child

  def remove_all_folders
    remove_all_children(:of_type => 'EmsFolder')
  end

  def get_folder_paths(folder = nil)
    exclude_root_folder = folder.nil?
    folder ||= ems_folder_root
    return [] if folder.nil?

    folder.child_folder_paths(
      :exclude_root_folder         => exclude_root_folder,
      :exclude_datacenters         => true,
      :exclude_non_display_folders => true
    )
  end

  def resource_pools_non_default
    if @association_cache.include?(:resource_pools)
      resource_pools.select { |r| !r.is_default }
    else
      resource_pools.where.not(is_default: true).to_a
    end
  end

  def event_where_clause(assoc = :ems_events)
    ["#{events_table_name(assoc)}.ems_id = ?", id]
  end

  def vm_count_by_state(state)
    vms.inject(0) { |t, vm| vm.power_state == state ? t + 1 : t }
  end

  def total_vms_on;        vm_count_by_state("on");        end

  def total_vms_off;       vm_count_by_state("off");       end

  def total_vms_unknown;   vm_count_by_state("unknown");   end

  def total_vms_never;     vm_count_by_state("never");     end

  def total_vms_suspended; vm_count_by_state("suspended"); end

  def get_reserve(field)
    (hosts + ems_clusters).inject(0) { |v, obj| v + (obj.send(field) || 0) }
  end

  def cpu_reserve
    get_reserve(:cpu_reserve)
  end

  def memory_reserve
    get_reserve(:memory_reserve)
  end

  #
  # Metric methods
  #

  PERF_ROLLUP_CHILDREN = [:hosts]

  def perf_rollup_parents(interval_name = nil)
    [MiqRegion.my_region].compact unless interval_name == 'realtime'
  end

  def perf_capture_enabled?
    return @perf_capture_enabled unless @perf_capture_enabled.nil?

    @perf_capture_enabled = ems_clusters.any?(&:perf_capture_enabled?) || host.any?(&:perf_capture_enabled?)
  end
  alias_method :perf_capture_enabled, :perf_capture_enabled?
  Vmdb::Deprecation.deprecate_methods(self, :perf_capture_enabled => :perf_capture_enabled?)

  # Some workers hold open a connection to the provider and thus do not
  # automatically pick up authentication changes.  These workers have to be
  # restarted manually for the new credentials to be used.
  def after_update_authentication
    stop_event_monitor_queue_on_credential_change
  end

  ###################################
  # Event Monitor
  ###################################

  def self.event_monitor_class
    nil
  end
  delegate :event_monitor_class, :to => :class

  def event_monitor
    return if event_monitor_class.nil?

    event_monitor_class.find_by_ems(self).first
  end

  def start_event_monitor
    return if event_monitor_class.nil?

    event_monitor_class.start_worker_for_ems(self)
  end

  def stop_event_monitor
    return if event_monitor_class.nil?

    _log.info("EMS [#{name}] id [#{id}]: Stopping event monitor.")
    event_monitor_class.stop_worker_for_ems(self)
  end

  def stop_event_monitor_queue
    MiqQueue.put_unless_exists(
      :class_name  => self.class.name,
      :method_name => "stop_event_monitor",
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :zone        => my_zone,
      :role        => "event"
    )
  end

  def stop_event_monitor_queue_on_change
    if event_monitor_class && !new_record? && default_endpoint.changed.include_any?("hostname", "ipaddress")
      _log.info("EMS: [#{name}], Hostname or IP address has changed, stopping Event Monitor.  It will be restarted by the WorkerMonitor.")
      stop_event_monitor_queue
    end
  end

  def stop_event_monitor_queue_on_credential_change
    if event_monitor_class && !new_record? && credentials_changed?
      _log.info("EMS: [#{name}], Credentials have changed, stopping Event Monitor.  It will be restarted by the WorkerMonitor.")
      stop_event_monitor_queue
    end
  end

  def blacklisted_event_names
    (
      self.class.blacklisted_events.where(:enabled => true).pluck(:event_name) +
      blacklisted_events.where(:enabled => true).pluck(:event_name)
    ).uniq.sort
  end

  def self.blacklisted_events
    BlacklistedEvent.where(:provider_model => name, :ems_id => nil)
  end

  ###################################
  # Refresh Worker
  ###################################

  def self.refresh_worker_class
    nil
  end
  delegate :refresh_worker_class, :to => :class

  def refresh_worker
    return if refresh_worker_class.nil?

    refresh_worker_class.find_by_ems(self).first
  end

  def start_refresh_worker
    return if refresh_worker_class.nil?

    refresh_worker_class.start_worker_for_ems(self)
  end

  def stop_refresh_worker
    return if refresh_worker_class.nil?

    _log.info("EMS [#{name}] id [#{id}]: Stopping Refresh Worker.")
    refresh_worker_class.stop_worker_for_ems(self)
  end

  def stop_refresh_worker_queue
    MiqQueue.put_unless_exists(
      :class_name  => self.class.name,
      :method_name => "stop_refresh_worker",
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :zone        => my_zone,
      :role        => "event"
    )
  end

  def stop_refresh_worker_queue_on_change
    if refresh_worker_class && !new_record? && default_endpoint.changed.include_any?("hostname", "ipaddress")
      _log.info("EMS: [#{name}], Hostname or IP address has changed, stopping Refresh Worker.  It will be restarted by the WorkerMonitor.")
      stop_refresh_worker_queue
    end
  end

  def stop_refresh_worker_queue_on_credential_change
    if refresh_worker_class && !new_record? && credentials_changed?
      _log.info("EMS: [#{name}], Credentials have changed, stopping Refresh Worker.  It will be restarted by the WorkerMonitor.")
      stop_refresh_worker_queue
    end
  end

  # Factory that takes a child class (e.g.: "NetworkRouter")
  #         and returns the EMS specific version of it
  # This can be overridden case by case in EMS specific implementations
  #
  # @param [String|Symbol] class_name name of the child class
  # @returns The EMS specific version of the class requested
  def self.class_by_ems(class_name)
    const_get(class_name, false)
  rescue NameError
    nil
  end
  delegate :class_by_ems, :to => :class

  def tenant_identity
    User.super_admin.tap { |u| u.current_group = tenant.default_miq_group }
  end

  def self.inventory_status
    data = includes(:zone)
           .select(:id, :parent_ems_id, :zone_id, :type, :name, :total_hosts, :total_vms, :total_clusters)
           .map do |ems|
             [
               ems.region_id, ems.zone.name, ems.class.short_token, ems.name,
               ems.total_clusters, ems.total_hosts, ems.total_vms, ems.total_storages,
               ems.try(:containers).try(:count),
               ems.try(:container_groups).try(:count),
               ems.try(:container_images).try(:count),
               ems.try(:container_nodes).try(:count),
               ems.try(:container_projects).try(:count),
             ]
           end
    return if data.empty?

    data = data.sort_by { |e| [e[0], e[1], e[2], e[3]] }
    # remove 0's (except for the region)
    data = data.map { |row| row.each_with_index.map { |col, i| i.positive? && col.to_s == "0" ? nil : col } }
    data.unshift(%w[region zone kind ems clusters hosts vms storages containers groups images nodes projects])
    # remove columns where all values (except for the header) are blank
    data.first.dup.each do |col_header|
      col = data.first.index(col_header)
      if data[1..-1].none? { |row| row[col] }
        data.each { |row| row.delete_at(col) }
      end
    end
    data
  end

  def self.display_name(number = 1)
    n_('Manager', 'Managers', number)
  end

  def allow_targeted_refresh?
    Settings.ems_refresh.fetch_path(emstype, :allow_targeted_refresh)
  end

  private

  def validate_ems_type
    errors.add(:base, "emstype #{self.class.name} is not permitted for create") unless ExtManagementSystem.permitted_types.include?(emstype)
  end

  def disable!(validate: true)
    _log.info("Disabling EMS [#{name}] id [#{id}].")
    self.enabled = false
    save(:validate => validate)
    _log.info("Disabling EMS [#{name}] id [#{id}] successful.")
  end

  def build_connection(options = {})
    build_endpoint_by_role(options[:endpoint])
    build_authentication_by_role(options[:authentication])
  end

  def build_endpoint_by_role(options)
    return if options.blank?

    endpoint = endpoints.detect { |e| e.role == options[:role].to_s }
    if endpoint
      endpoint.assign_attributes(options)
    else
      endpoints.build(options)
    end
  end

  def build_authentication_by_role(options)
    return if options.blank?

    role = options.delete(:role)
    creds = {}
    creds[role] = options
    update_authentication(creds, options)
  end

  define_method(:allow_duplicate_endpoint_url?) { false }
end
