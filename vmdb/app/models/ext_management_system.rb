class ExtManagementSystem < ActiveRecord::Base
  include EmsRefresh::Manager

  def self.types
    [EmsInfra, EmsCloud].collect(&:types).flatten
  end

  def self.supported_types
    [EmsInfra, EmsCloud].collect(&:supported_types).flatten
  end

  def self.leaf_subclasses
    [EmsInfra, EmsCloud].collect(&:subclasses).flatten
  end

  def self.supported_subclasses
    [EmsInfra, EmsCloud].collect(&:supported_subclasses).flatten
  end

  def self.supported_types_and_descriptions_hash
    supported_subclasses.each_with_object({}) do |klass, hash|
      hash[klass.ems_type] = klass.description
    end
  end

  has_many :hosts,  :foreign_key => "ems_id", :dependent => :nullify
  has_many :vms_and_templates, :foreign_key => "ems_id", :dependent => :nullify, :class_name => "VmOrTemplate"
  has_many :miq_templates,     :foreign_key => :ems_id
  has_many :vms,               :foreign_key => :ems_id

  has_many :ems_events,     -> { order "timestamp" }, :class_name => "EmsEvent",    :foreign_key => "ems_id"
  has_many :policy_events,  -> { order "timestamp" }, :class_name => "PolicyEvent", :foreign_key => "ems_id"

  has_many :ems_folders,    :foreign_key => "ems_id", :dependent => :destroy
  has_many :ems_clusters,   :foreign_key => "ems_id", :dependent => :destroy
  has_many :resource_pools, :foreign_key => "ems_id", :dependent => :destroy

  has_many :customization_specs, :foreign_key => "ems_id", :dependent => :destroy

  has_one  :iso_datastore, :foreign_key => "ems_id", :dependent => :destroy

  belongs_to :zone

  has_many :metrics,        :as => :resource  # Destroy will be handled by purger
  has_many :metric_rollups, :as => :resource  # Destroy will be handled by purger
  has_many :vim_performance_states, :as => :resource  # Destroy will be handled by purger

  validates :name,                 :presence => true, :uniqueness => true
  validates :hostname, :ipaddress, :presence => true, :uniqueness => {:case_sensitive => false}, :if => :hostname_ipaddress_required?

  include NewWithTypeStiMixin
  include UuidMixin
  include WebServiceAttributeMixin


  after_destroy { |record| $log.info "MIQ(ExtManagementSystem.after_destroy) Removed EMS [#{record.name}] id [#{record.id}]" }

  # attr_accessor :userid
  # attr_accessor :password

  acts_as_miq_taggable

  include FilterableMixin
  include ReportableMixin

  include EventMixin

  include MiqPolicyMixin

  include RelationshipMixin
  self.default_relationship_type = "ems_metadata"

  include AggregationMixin
  # Since we've overridden the implementation of methods from AggregationMixin,
  # we must also override the :uses portion of the virtual columns.
  override_aggregation_mixin_virtual_columns_uses(:all_hosts, :hosts)
  override_aggregation_mixin_virtual_columns_uses(:all_vms_and_templates, :vms_and_templates)

  include AuthenticationMixin
  include Metric::CiMixin
  include AddressMixin
  include AsyncDeleteMixin

  virtual_column :emstype,                 :type => :string
  virtual_column :emstype_description,     :type => :string
  virtual_column :last_refresh_status,     :type => :string
  virtual_column :total_vms_and_templates, :type => :integer
  virtual_column :total_vms,               :type => :integer
  virtual_column :total_miq_templates,     :type => :integer
  virtual_column :total_hosts,             :type => :integer
  virtual_column :total_storages,          :type => :integer
  virtual_column :total_clusters,          :type => :integer
  virtual_column :zone_name,               :type => :string,  :uses => :zone
  virtual_column :total_vms_on,            :type => :integer
  virtual_column :total_vms_off,           :type => :integer
  virtual_column :total_vms_unknown,       :type => :integer
  virtual_column :total_vms_never,         :type => :integer
  virtual_column :total_vms_suspended,     :type => :integer

  alias clusters ems_clusters # Used by web-services to return clusters as the property name

  EMS_DISCOVERY_TYPES = {
    'vmware'    => 'virtualcenter',
    'microsoft' => 'scvmm',
    'redhat'    => 'rhevm',
  }

  def self.create_discovered_ems(ost)
    # add an ems entry
    if ExtManagementSystem.find_by_ipaddress(ost.ipaddr).nil?
      hostname = Socket.getaddrinfo(ost.ipaddr, nil)[0][2]

      ems_klass, ems_name = if ost.hypervisor.include?(:scvmm)
        [EmsMicrosoft, 'SCVMM']
      elsif ost.hypervisor.include?(:rhevm)
        [EmsRedhat, 'RHEV-M']
      else
        [EmsVmware, 'Virtual Center']
      end

      ems = ems_klass.create(
        :ipaddress => ost.ipaddr,
        :name      => "#{ems_name} (#{ost.ipaddr})",
        :hostname  => hostname,
        :zone_id   => MiqServer.my_server.zone.id
      )

      $log.info "MIQ(#{self.name}.create_discovered): #{ui_lookup(:table => "ext_management_systems")} #{ems.name} created"
      AuditEvent.success(:event => "ems_created", :target_id => ems.id, :target_class => "ExtManagementSystem", :message => "#{ui_lookup(:table => "ext_management_systems")} #{ems.name} created")
    end
  end

  def self.model_name_from_emstype(emstype)
    leaf_subclasses.each do |k|
      return k.name if k.ems_type == emstype.downcase
    end
    return nil
  end

  def self.model_from_emstype(emstype)
    model_name_from_emstype(emstype).constantize
  end

  # UI methods for determining availability of fields
  def supports_port?
    false
  end

  def supports_authentication?(authtype)
    authtype.to_s == "default"
  end

  # UI method for determining which icon to show for a particular EMS
  def image_name
    emstype.downcase
  end

  def authentication_check_role
    'ems_operations'
  end

  def to_s
    self.name
  end

  def hostname_ipaddress_required?
    true
  end

  def my_zone
    zone = self.zone
    zone.nil? || zone.name.blank? ? MiqServer.my_zone : zone.name
  end
  alias zone_name my_zone

  def emstype_description
    self.class.description || self.emstype.titleize
  end

  def with_provider_connection(options = {})
    raise "no block given" unless block_given?
    $log.info("MIQ(#{self.class.name}.with_provider_connection) Connecting through #{self.class.name}: [#{self.name}]")
    yield connect(options)
  end

  def self.refresh_all_ems_timer
    ems_ids = self.where(:zone_id => MiqServer.my_server.zone.id).pluck(:id)
    self.refresh_ems(ems_ids, true) unless ems_ids.empty?
  end

  def self.refresh_ems(ems_ids, reload = false)
    ems_ids = [ems_ids] unless ems_ids.kind_of?(Array)

    ExtManagementSystem.find_all_by_id(ems_ids).each { |ems| ems.reset_vim_cache_queue if ems.respond_to?(:reset_vim_cache_queue) } if reload

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

  def refresh_ems
    raise "no #{ui_lookup(:table => "ext_management_systems")} credentials defined" if self.authentication_invalid?
    raise "refresh requires a valid user id and password" if self.authentication_invalid?
    EmsRefresh.queue_refresh(self)
  end

  def self.ems_discovery_types
    EMS_DISCOVERY_TYPES.values
  end

  def disconnect_inv
    self.hosts.each { |h| h.disconnect_ems(self) }
    self.vms.each   { |v| v.disconnect_ems(self) }

    self.ems_folders.destroy_all
    self.ems_clusters.destroy_all
    self.resource_pools.destroy_all
  end

  def enforce_policy(target, event)
    inputs = { :ext_management_system => self }
    inputs[:vm]   = target if target.kind_of?(Vm)
    inputs[:host] = target if target.kind_of?(Host)
    MiqEvent.raise_evm_event(target, event, inputs)
  end

  def non_clustered_hosts
    self.hosts.select { |h| h.ems_cluster.nil? }
  end

  def clustered_hosts
    self.hosts.select { |h| !h.ems_cluster.nil? }
  end

  def miq_proxies
    MiqProxy.all.select { |p| p.ext_management_system == self }
  end

  def clear_association_cache_with_storages
    @storages = nil
    self.clear_association_cache_without_storages
  end
  alias_method_chain :clear_association_cache, :storages

  alias storages               all_storages
  alias datastores             all_storages  # Used by web-services to return datastores as the property name

  alias all_hosts              hosts
  alias all_host_ids           host_ids
  alias all_vms_and_templates  vms_and_templates
  alias all_vm_or_template_ids vm_or_template_ids
  alias all_vms                vms
  alias all_vm_ids             vm_ids
  alias all_miq_templates      miq_templates
  alias all_miq_template_ids   miq_template_ids

  #
  # Relationship methods
  #

  # Folder relationship methods
  def ems_folder_root
    self.folders.first
  end

  def folders
    self.children(:of_type => 'EmsFolder').sort_by { |c| c.name.downcase }
  end

  alias add_folder    set_child
  alias remove_folder remove_child

  def remove_all_folders
    self.remove_all_children(:of_type => 'EmsFolder')
  end

  def get_folder_paths(folder = nil)
    exclude_root_folder = folder.nil?
    folder ||= self.ems_folder_root
    return [] if folder.nil?
    folder.child_folder_paths(
      :exclude_root_folder => exclude_root_folder,
      :exclude_datacenters => true,
      :exclude_non_display_folders => true
    )
  end

  def resource_pools_non_default
    if association_cache.include?(:resource_pools)
      self.resource_pools.select { |r| !r.is_default }
    else
      self.resource_pools.where("is_default != ?", true).to_a
    end
  end

  def event_where_clause(assoc)
    ["ems_id = ?", self.id]
  end

  def total_vms_and_templates
    self.vms_and_templates.size
  end

  def total_vms
    self.vms.size
  end

  def total_miq_templates
    self.miq_templates.size
  end

  def total_hosts
    self.hosts.size
  end

  def total_clusters
    self.ems_clusters.size
  end

  def total_storages
    HostsStorages.count(:conditions => {:host_id => self.host_ids}, :select => "DISTINCT storage_id")
  end

  def vm_count_by_state(state)
    self.vms.inject(0) { |t, vm| vm.power_state == state ? t + 1 : t }
  end
  def total_vms_on;        vm_count_by_state("on");        end
  def total_vms_off;       vm_count_by_state("off");       end
  def total_vms_unknown;   vm_count_by_state("unknown");   end
  def total_vms_never;     vm_count_by_state("never");     end
  def total_vms_suspended; vm_count_by_state("suspended"); end

  def get_reserve(field)
    (self.hosts + self.ems_clusters).inject(0) {|v,obj| v + (obj.send(field) || 0)}
  end

  def cpu_reserve
    get_reserve(:cpu_reserve)
  end

  def memory_reserve
    get_reserve(:memory_reserve)
  end

  def vm_log_user_event(vm, user_event)
    $log.info(user_event)
    $log.warn "User event logging is not available on [#{self.class.name}] Name:[#{self.name}]"
  end

  #
  # Metric methods
  #

  PERF_ROLLUP_CHILDREN = :hosts

  def perf_rollup_parent(interval_name=nil)
    MiqRegion.my_region unless interval_name == 'realtime'
  end

  def perf_capture_enabled
    return @perf_capture_enabled unless @perf_capture_enabled.nil?
    return @perf_capture_enabled = true if self.ems_clusters.any?(&:perf_capture_enabled?)
    return @perf_capture_enabled = true if self.hosts.any?(&:perf_capture_enabled?)
    return @perf_capture_enabled = false
  end
  alias perf_capture_enabled? perf_capture_enabled

  ###################################
  # Event Monitor
  ###################################

  def after_update_authentication
    stop_event_monitor_queue_on_credential_change
  end

  def self.event_monitor_class
    nil
  end

  def event_monitor_class
    self.class.event_monitor_class
  end

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
    $log.info "MIQ(#{self.class.name}#stop_event_monitor) EMS [#{self.name}] id [#{self.id}]: Stopping event monitor."
    event_monitor_class.stop_worker_for_ems(self)
  end

  def stop_event_monitor_queue
    MiqQueue.put_unless_exists(
      :class_name  => self.class.name,
      :method_name => "stop_event_monitor",
      :instance_id => self.id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :zone        => self.my_zone,
      :role        => "event"
    )
  end

  def stop_event_monitor_queue_on_change
    if !self.event_monitor_class.nil? && !self.new_record? && self.changed.include_any?("hostname", "ipaddress")
      $log.info("MIQ(#{self.class.name}#stop_event_monitor_queue) EMS: [#{self.name}], Hostname or IP address has changed, stopping Event Monitor.  It will be restarted by the WorkerMonitor.")
      self.stop_event_monitor_queue
    end
  end

  def stop_event_monitor_queue_on_credential_change
    if !self.event_monitor_class.nil? && !self.new_record? && self.credentials_changed?
      $log.info("MIQ(#{self.class.name}#stop_event_monitor_queue) EMS: [#{self.name}], Credentials have changed, stopping Event Monitor.  It will be restarted by the WorkerMonitor.")
      self.stop_event_monitor_queue
    end
  end
end
