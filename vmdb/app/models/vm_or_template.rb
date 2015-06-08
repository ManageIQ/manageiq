require 'ostruct'
require 'cgi'
require 'uri'

class VmOrTemplate < ActiveRecord::Base
  include NewWithTypeStiMixin

  self.table_name = 'vms'

  include_concern 'Operations'
  include_concern 'RetirementManagement'
  include_concern 'RightSizing'
  include_concern 'Scanning'
  include_concern 'Snapshotting'

  attr_accessor :surrogate_host
  @surrogate_host = nil

  include SerializedEmsRefObjMixin
  include ProviderObjectMixin

  include ComplianceMixin
  include OwnershipMixin
  include CustomAttributeMixin
  include WebServiceAttributeMixin

  include EventMixin
  include ProcessTasksMixin

  has_many :ems_custom_attributes, :as => :resource, :dependent => :destroy, :class_name => "CustomAttribute", :conditions => "source = 'VC'"

  VENDOR_TYPES = {
    # DB            Displayed
    "vmware"    => "VMware",
    "microsoft" => "Microsoft",
    "xen"       => "XenSource",
    "parallels" => "Parallels",
    "amazon"    => "Amazon",
    "redhat"    => "RedHat",
    "openstack" => "OpenStack",
    "unknown"   => "Unknown"
  }

  POWER_OPS = %w{start stop suspend reset shutdown_guest standby_guest reboot_guest}

  validates_presence_of     :name, :location
  #validates_uniqueness_of   :name
  validates_inclusion_of    :vendor, :in => VENDOR_TYPES.values

  has_one                   :miq_server, :foreign_key => :vm_id

  has_one                   :operating_system, :dependent => :destroy
  has_one                   :hardware, :dependent => :destroy
  belongs_to                :host
  belongs_to                :ems_cluster

  belongs_to                :storage
  has_many                  :repositories, :through => :storage
  has_and_belongs_to_many   :storages

  belongs_to                :ext_management_system, :foreign_key => "ems_id"

  has_one                   :miq_provision, :dependent => :nullify, :as => :destination
  has_many                  :miq_provisions_from_template, :class_name => "MiqProvision", :as => :source, :dependent => :nullify
  has_many                  :miq_provision_vms, :through => :miq_provisions_from_template, :source => :vm, :class_name => "Vm"
  has_many                  :miq_provision_requests, :as => :source, :dependent => :destroy

  has_many                  :guest_applications, :dependent => :destroy
  has_many                  :patches, :dependent => :destroy

  # Accounts - Users and Groups
  has_many                  :accounts, :dependent => :destroy
  has_many                  :users,  :class_name => "Account", :conditions => {:accttype => 'user'}
  has_many                  :groups, :class_name => "Account", :conditions => {:accttype => 'group'}

  # System Services - Win32_Services, Kernel drivers, Filesystem drivers
  has_many                  :system_services, :dependent => :destroy
  has_many                  :win32_services,      :class_name => "SystemService", :conditions => "typename = 'win32_service'"
  has_many                  :kernel_drivers,      :class_name => "SystemService", :conditions => "typename = 'kernel' OR typename = 'misc'"
  has_many                  :filesystem_drivers,  :class_name => "SystemService", :conditions => "typename = 'filesystem'"
  has_many                  :linux_initprocesses, :class_name => "SystemService", :conditions => "typename = 'linux_initprocess' OR typename = 'linux_systemd'"

  has_many                  :filesystems, :as => :resource, :dependent => :destroy
  has_many                  :directories, :as => :resource, :class_name => "Filesystem", :conditions => "rsc_type = 'dir'"
  has_many                  :files,       :as => :resource, :class_name => "Filesystem", :conditions => "rsc_type = 'file'"

  has_many                  :scan_histories,    :dependent => :destroy
  has_many                  :lifecycle_events,  :class_name => "LifecycleEvent"
  has_many                  :advanced_settings, :as => :resource, :dependent => :destroy

  # Scan Items
  has_many                  :registry_items, :dependent => :destroy

  has_many                  :metrics,        :as => :resource  # Destroy will be handled by purger
  has_many                  :metric_rollups, :as => :resource  # Destroy will be handled by purger
  has_many                  :vim_performance_states, :as => :resource  # Destroy will be handled by purger

  has_many                  :storage_files, :dependent => :destroy
  has_many                  :storage_files_files, :class_name => "StorageFile", :conditions => "rsc_type = 'file'"

  # EMS Events
  has_many                  :ems_events, :class_name => "EmsEvent",
    :finder_sql  => lambda { |_| EmsEvent.where("vm_or_template_id = ? OR dest_vm_or_template_id = ?", id, id).order(:timestamp).to_sql },
    :counter_sql => lambda { |_| EmsEvent.where("vm_or_template_id = ? OR dest_vm_or_template_id = ?", id, id).select("COUNT(*)").to_sql }
  has_many                  :ems_events_src,  :class_name => "EmsEvent"
  has_many                  :ems_events_dest, :class_name => "EmsEvent", :foreign_key => :dest_vm_or_template_id

  has_many                  :policy_events, :class_name => "PolicyEvent",
    :finder_sql  => lambda { |_| PolicyEvent.where("target_id = ? OR target_class = 'VmOrTemplate'", id).order(:timestamp).to_sql },
    :counter_sql => lambda { |_| PolicyEvent.where("target_id = ? OR target_class = 'VmOrTemplate'", id).select("COUNT(*)").to_sql }

  has_many                  :miq_alert_statuses, :dependent => :destroy, :as => :resource

  has_one                   :miq_cim_instance, :as => :vmdb_obj, :dependent => :destroy

  has_many                  :service_resources, :as => :resource
#  has_many                  :service_templates, :through => :service_resources, :source => :service_template
  has_many                  :direct_services, :through => :service_resources, :source => :service


  acts_as_miq_taggable
  include ReportableMixin

  virtual_column :active,                               :type => :boolean
  virtual_column :archived,                             :type => :boolean,    :uses => [:host, :storage]
  virtual_column :orphaned,                             :type => :boolean,    :uses => [:host, :storage]
  virtual_column :disconnected,                         :type => :boolean
  virtual_column :is_evm_appliance,                     :type => :boolean,    :uses => :miq_server
  virtual_column :os_image_name,                        :type => :string,     :uses => [:operating_system, :hardware]
  virtual_column :platform,                             :type => :string,     :uses => [:operating_system, :hardware]
  virtual_column :v_host_vmm_product,                   :type => :string,     :uses => :host
  virtual_column :v_is_a_template,                      :type => :string
  virtual_column :v_owning_cluster,                     :type => :string,     :uses => :ems_cluster
  virtual_column :v_owning_resource_pool,               :type => :string,     :uses => :all_relationships
  virtual_column :v_owning_datacenter,                  :type => :string,     :uses => {:ems_cluster => :all_relationships}
  virtual_column :v_owning_folder,                      :type => :string,     :uses => {:ems_cluster => :all_relationships}
  virtual_column :v_owning_folder_path,                 :type => :string,     :uses => {:ems_cluster => :all_relationships}
  virtual_column :v_owning_blue_folder,                 :type => :string,     :uses => :all_relationships
  virtual_column :v_owning_blue_folder_path,            :type => :string,     :uses => :all_relationships
  virtual_column :v_pct_free_disk_space,                :type => :float,      :uses => :hardware
  virtual_column :v_pct_used_disk_space,                :type => :float,      :uses => :v_pct_free_disk_space
  virtual_column :v_datastore_path,                     :type => :string,     :uses => :storage
  virtual_column :thin_provisioned,                     :type => :boolean,    :uses => {:hardware => :disks}
  virtual_column :used_disk_storage,                    :type => :integer,    :uses => {:hardware => :disks}
  virtual_column :allocated_disk_storage,               :type => :integer,    :uses => {:hardware => :disks}
  virtual_column :provisioned_storage,                  :type => :integer,    :uses => [:allocated_disk_storage, :mem_cpu]
  virtual_column :used_storage,                         :type => :integer,    :uses => [:used_disk_storage, :mem_cpu]
  virtual_column :used_storage_by_state,                :type => :integer,    :uses => :used_storage
  virtual_column :uncommitted_storage,                  :type => :integer,    :uses => [:provisioned_storage, :used_storage_by_state]
  virtual_column :mem_cpu,                              :type => :integer,    :uses => :hardware
  virtual_column :ems_cluster_name,                     :type => :string,     :uses => :ems_cluster
  virtual_column :host_name,                            :type => :string,     :uses => :host
  virtual_column :ipaddresses,                          :type => :string_set, :uses => {:hardware => :ipaddresses}
  virtual_column :hostnames,                            :type => :string_set, :uses => {:hardware => :hostnames}
  virtual_column :mac_addresses,                        :type => :string_set, :uses => {:hardware => :mac_addresses}
  virtual_column :storage_name,                         :type => :string,     :uses => :storage
  virtual_column :memory_exceeds_current_host_headroom, :type => :string,     :uses => [:mem_cpu, {:host => [:hardware, :ext_management_system]}]
  virtual_column :num_hard_disks,                       :type => :integer,    :uses => {:hardware => :hard_disks}
  virtual_column :num_disks,                            :type => :integer,    :uses => {:hardware => :disks}
  virtual_column :num_cpu,                              :type => :integer,    :uses => :hardware
  virtual_column :logical_cpus,                         :type => :integer,    :uses => :hardware
  virtual_column :cores_per_socket,                     :type => :integer,    :uses => :hardware
  virtual_column :v_annotation,                         :type => :string,     :uses => :hardware
  virtual_column :has_rdm_disk,                         :type => :boolean,    :uses => {:hardware => :disks}
  virtual_column :disks_aligned,                        :type => :string,     :uses => {:hardware => {:hard_disks => :partitions_aligned}}

  virtual_has_many   :processes,              :class_name => "OsProcess",    :uses => {:operating_system => :processes}
  virtual_has_many   :event_logs,                                            :uses => {:operating_system => :event_logs}
  virtual_has_many   :lans,                                                  :uses => {:hardware => {:nics => :lan}}
  virtual_belongs_to :miq_provision_template, :class_name => "Vm",           :uses => {:miq_provision => :vm_template}
  virtual_belongs_to :parent_resource_pool,   :class_name => "ResourcePool", :uses => :all_relationships

  virtual_has_many  :base_storage_extents, :class_name => "CimStorageExtent"
  virtual_has_many  :storage_systems,      :class_name => "CimComputerSystem"
  virtual_has_many  :file_shares,          :class_name => 'SniaFileShare'
  virtual_has_many  :storage_volumes,      :class_name => 'CimStorageVolume'
  virtual_has_many  :logical_disks,        :class_name => 'CimLogicalDisk'

  virtual_has_one   :direct_service,       :class_name => 'Service'
  virtual_has_one   :service,              :class_name => 'Service'

  alias datastores storages    # Used by web-services to return datastores as the property name

  alias parent_cluster ems_cluster
  alias owning_cluster ems_cluster

  # Add virtual columns/methods for specific things derived from advanced_settings
  REQUIRED_ADVANCED_SETTINGS = {
    'vmi.present'         => [:paravirtualization,   :boolean],
    'vmsafe.enable'       => [:vmsafe_enable,        :boolean],
    'vmsafe.agentAddress' => [:vmsafe_agent_address, :string],
    'vmsafe.agentPort'    => [:vmsafe_agent_port,    :integer],
    'vmsafe.failOpen'     => [:vmsafe_fail_open,     :boolean],
    'vmsafe.immutableVM'  => [:vmsafe_immutable_vm,  :boolean],
    'vmsafe.timeoutMS'    => [:vmsafe_timeout_ms,    :integer],
  }
  REQUIRED_ADVANCED_SETTINGS.each do |k, (m, t)|
    define_method(m) do
      as = self.advanced_settings.detect { |as| as.name == k }
      return nil if as.nil? || as.value.nil?

      return case t
      when :boolean then ActiveRecord::ConnectionAdapters::Column.value_to_boolean(as.value)
      when :integer then as.value.to_i
      else as.value.to_s
      end
    end

    virtual_column m, :type => t, :uses => :advanced_settings
  end

  # Add virtual columns/methods for details about each disk
  (1..9).each do |i|
    disk_methods = [
      ['disk_type',                   :string],
      ['mode',                        :string],
      ['size',                        :integer],
      ['size_on_disk',                :integer],
      ['used_percent_of_provisioned', :float],
      ['partitions_aligned',          :string]
    ]

    disk_methods.each do |k, t|
      m  = "disk_#{i}_#{k}".to_sym

      define_method(m) do
        return nil if self.hardware.nil?
        return nil if self.hardware.hard_disks.length < i
        self.hardware.hard_disks[i - 1].send(k)
      end

      virtual_column m, :type => t, :uses => {:hardware => :hard_disks}
    end
  end

  # Add virtual columns/methods for accessing individual folders in a path
  (1..9).each do |i|
    m = "parent_blue_folder_#{i}_name".to_sym

    define_method(m) do
      f = self.parent_blue_folders(:exclude_root_folder => true, :exclude_non_display_folders => true)[i - 1]
      f.nil? ? "" : f.name
    end

    virtual_column m, :type => :string, :uses => :all_relationships
  end

  def v_annotation
    return nil if self.hardware.nil?
    self.hardware.annotation
  end

  include RelationshipMixin
  self.default_relationship_type = "genealogy"

  include MiqPolicyMixin
  include AlertMixin
  include DriftStateMixin
  include UuidMixin
  include Metric::CiMixin

  include FilterableMixin
  include StorageMixin

  def to_s
    self.name
  end

  def is_evm_appliance?
    !!self.miq_server
  end
  alias is_evm_appliance  is_evm_appliance?

  # Determines if the VM is on an EMS or Host
  def registered?
    #TODO: Vmware specific
    return false if self.template? && self.ext_management_system.nil?
    return false if self.host.nil?
    return true
  end

  # TODO: Vmware specific, and is this even being used anywhere?
  def connected_to_ems?
    self.connection_state == 'connected'
  end

  def raw_set_custom_field(attribute, value)
    raise "VM has no EMS, unable to set custom attribute" unless self.ext_management_system
    run_command_via_parent(:vm_set_custom_field, :attribute => attribute, :value => value)
  end

  def set_custom_field(attribute, value)
    raw_set_custom_field(attribute, value)
  end

  def makesmart(options = {})
    self.smart = true
    self.save
  end

  # Ask host to update all locally registered vm state data
  def refresh_state
    begin
      run_command_via_parent("SendVMState")
    rescue => err
      $log.log_backtrace(err)
    end
  end

  def run_command_via_parent(verb, options = {})
    raise "VM/Template <#{name}> with Id: <#{id}> is not associated with a provider." unless self.ext_management_system
    raise "VM/Template <#{name}> with Id: <#{id}>: Provider authentication failed." unless self.ext_management_system.authentication_status_ok?

    # TODO: Need to break this logic out into a method that can look at the verb and the vm and decide the best way to invoke it - Virtual Center WS, ESX WS, Storage Proxy.
    $log.info("MIQ(#{self.class.name}#run_command_via_parent) Invoking [#{verb}] through provider: [#{self.ext_management_system.name}]")
    options = {:user_event => "Console Request Action [#{verb}], VM [#{self.name}]"}.merge(options)
    self.ext_management_system.send(verb, self, options)
  end

  def policy_prevented?(policy_event)
    begin
      enforce_policy(policy_event) unless policy_event.nil?
      return false
    rescue MiqException::PolicyPreventAction => err
      $log.info "MIQ(#{self.class.name}#policy_prevented?) #{err}"
      return true
    end
  end

  def enforce_policy(event, inputs = {})
    return  {"result" => true, :details => []} if event.to_s == "rsop" && self.host.nil?
    raise "vm does not belong to any host" if self.host.nil? && self.ext_management_system.nil?

    inputs[:vm]                    = self
    inputs[:host]                  = self.host                  unless self.host.nil?
    inputs[:ext_management_system] = self.ext_management_system unless self.ext_management_system.nil?
    MiqEvent.raise_evm_event(self, event, inputs)
  end

  # override
  def self.validate_task(task, vm, options)
    return false unless super
    return false if options[:task] == "destroy" ||  options[:task] == "check_compliance_queue"
    return false if vm.has_required_host?

    # VM has no host or storage affiliation
    if vm.storage.nil?
      task.error("#{vm.name}: There is no owning Host or #{ui_lookup(:table => "storages")} for this VM, "\
                 "'#{options[:task]}' is not allowed")
      return false
    end

    # VM belongs to a storage/repository location
    # TODO: The following never gets run since the invoke tasks invokes it as a job, and only tasks get to this point ?
    unless %w(scan sync).include?(options[:task])
      task.error("#{vm.name}: There is no owning Host for this VM, '#{options[:task]}' is not allowed")
      return false
    end
    current = VMDB::Config.new("vmdb")      # Get the vmdb configuration settings
    spid = current.config[:repository_scanning][:defaultsmartproxy]
    if spid.nil?                          # No repo scanning SmartProxy configured
      task.error("#{vm.name}: No Default Repository SmartProxy is configured, contact your EVM administrator")
      return false
    elsif MiqProxy.exists?(spid) == false
      task.error("#{vm.name}: The Default Repository SmartProxy no longer exists, contact your EVM Administrator")
      return false
    end
    if MiqProxy.find(spid).state != "on"                     # Repo scanning host iagent s not running
      task.error("#{vm.name}: The Default Repository SmartProxy, '#{sp.name}', is not running. "\
                 "'#{options[:task]}' not attempted")
      return false
    end
    true
  end
  private_class_method :validate_task

  # override
  def self.task_invoked_by(options)
    %w(scan sync).include?(options[:task]) ? :job : super
  end
  private_class_method :task_invoked_by

  # override
  def self.task_arguments(options)
    case options[:task]
    when "scan", "sync" then
      [options[:userid]]
    when "remove_snapshot", "revert_to_snapshot" then
      [options[:snap_selected]]
    when "create_snapshot" then
      [options[:name], options[:description], options[:memory]]
    else
      super
    end
  end
  private_class_method :task_arguments

  def powerops_callback(task_id, status, msg, result, queue_item)
    if queue_item.last_exception.kind_of?(MiqException::MiqVimBrokerUnavailable)
      queue_item.requeue(:deliver_on => 1.minute.from_now.utc)
    else
      task = MiqTask.find_by_id(task_id)
      task.queue_callback("Finished", status, msg, result) if task
    end
  end

  def self.powerops_expiration
    (VMDB::Config.new('vmdb').config.fetch_path(:management_system, :power_operation_expiration) || 10.minutes).to_i_with_method.seconds.from_now.utc
  end

  # override
  def self.invoke_task_local(task, vm, options, args)
    cb = nil
    if task
      cb =
        if POWER_OPS.include?(options[:task])
          {
            :class_name  => vm.class.base_class.name,
            :instance_id => vm.id,
            :method_name => :powerops_callback,
            :args        => [task.id]
          }
        else
          {
            :class_name  => task.class.to_s,
            :instance_id => task.id,
            :method_name => :queue_callback,
            :args        => ["Finished"]
          }
        end
    end

    role = options[:invoke_by] == :job ? "smartstate" : "ems_operations"
    role = nil if options[:task] == "destroy"
    MiqQueue.put(
      :class_name   => base_class.name,
      :instance_id  => vm.id,
      :method_name  => options[:task],
      :args         => args,
      :miq_callback => cb,
      :zone         => vm.my_zone,
      :role         => role,
      :expires_on   => POWER_OPS.include?(options[:task]) ? powerops_expiration : nil
    )
  end

  def self.invoke_tasks_remote(options)
    ids_by_region = options[:ids].group_by { |id| ActiveRecord::Base.id_to_region(id.to_i) }
    ids_by_region.each do |region, ids|
      remote_options = options.merge(:ids => ids)
      hostname = MiqRegion.find_by_region(region).remote_ws_address
      if hostname.nil?
        $log.error("An error occurred while invoking remote tasks...The remote region [#{region}] does not have a web service address.")
        next
      end

      begin
        client = VmdbwsClient.new(hostname)
        client.vm_invoke_tasks(remote_options)
      rescue => err
        # Handle specific error case, until we can figure out how it occurs
        if err.class == ArgumentError && err.message == "cannot interpret as DNS name: nil"
          $log.error("An error occurred while invoking remote tasks...")
          $log.log_backtrace(err)
          next
        end

        $log.error("An error occurred while invoking remote tasks...Requeueing for 1 minute from now.")
        $log.log_backtrace(err)
        MiqQueue.put(
          :class_name  => self.base_class.name,
          :method_name => 'invoke_tasks_remote',
          :args        => [remote_options],
          :deliver_on  => Time.now.utc + 1.minute
        )
        next
      end

      msg = "'#{options[:task]}' successfully initiated for remote VMs: #{ids.sort.inspect}"
      task_audit_event(:success, options, :message => msg)
    end
  end

  def scan_data_current?
    return !(self.last_scan_on.nil? || self.last_scan_on > self.last_sync_on)
  end

  def genealogy_parent
    self.with_relationship_type("genealogy") { self.parent }
  end

  def os_image_name
    name = OperatingSystem.image_name(self)
    if name == 'unknown'
      parent = genealogy_parent
      name = OperatingSystem.image_name(parent) unless parent.nil?
    end
    name
  end

  def platform
    name = OperatingSystem.platform(self)
    if name == 'unknown'
      parent = genealogy_parent
      name = OperatingSystem.platform(parent) unless parent.nil?
    end
    name
  end

  def product_name
    name   = self.try(:operating_system).try(:product_name)
    name ||= genealogy_parent.try(:operating_system).try(:product_name)
    name ||= ""
    name
  end

  def service_pack
    name   = self.try(:operating_system).try(:service_pack)
    name ||= genealogy_parent.try(:operating_system).try(:service_pack)
    name ||= ""
    name
  end

  # Generates the contents of the RSS feed that lists VMs that fail policy
  def self.rss_fails_policy(name, options)
    result = []
    vms = self.find(:all,
      :order => options[:orderby],
      :limit => options[:limit_to_count]
    ).each {|vm|
      rec = OpenStruct.new(vm.attributes)
      if vm.host.nil?
        rec.host_name = "unknown"
      else
        rec.host_name = vm.host.name
      end
      rec.vm_id = vm.id
      rec.reason = []
      presult = vm.enforce_policy("rsop")
      if presult[:result] == false
        presult[:details].each {|p|
          rec.reason.push(p["description"]) unless p["result"]
        }
        if rec.reason != []
          rec.reason = rec.reason.join(", ")
          result.push(rec)
        end
      end
    }
    result
  end

  def vendor
    v = read_attribute(:vendor)
    return VENDOR_TYPES[v]
  end

  def vendor=(v)
    unless VENDOR_TYPES.has_key?(v)
      v = VENDOR_TYPES.key(v)
      raise "vendor must be one of VENDOR_TYPES" unless VENDOR_TYPES.has_key?(v)
    end
    write_attribute(:vendor, v)
  end

  #
  # Path/location methods
  #

  # TODO: Vmware specific URI methods?  Next 3 methods
  def self.location2uri(location, scheme="file")
    pat = %r{^(file|http|miq)://([^/]*)/(.+)$}
    if !(pat =~ location)
      #location = scheme<<"://"<<self.myhost.ipaddress<<":1139/"<<location
      location = scheme << ":///" << location
    end
    return location
  end

  def self.uri2location(location)
    uri = URI.parse(location)
    location = URI.decode(uri.path)
    location = location[1..-1] if location[2..2] == ':'
    return location
  end

  def uri2location
    self.class.uri2location(self.location)
  end

  def save_scan_history(datahash)
    result = self.scan_histories.build(
      :status => datahash['status'],
      :status_code => datahash['status_code'].to_i,
      :message => datahash['message'],
      :started_on => Time.parse(datahash['start_time']),
      :finished_on => Time.parse(datahash['end_time']),
      :task_id => datahash['taskid']
    )
    self.last_scan_on = Time.parse(datahash['start_time'])
    self.save
    result
  end

  # TODO: Vmware specific
  def self.find_by_full_location(path)
    log_header = "MIQ(#{self.name}.find_by_full_location)"
    return nil if path.blank?
    vm_hash = {}
    begin
      vm_hash[:name], vm_hash[:location], vm_hash[:store_type] = Repository.parse_path(path)
    rescue => err
      $log.warn("#{log_header} Warning: [#{err.message}]")
      vm_hash[:location] = location2uri(path)
    end
    $log.info("#{log_header} vm_hash [#{vm_hash.inspect}]")
    store = Storage.find_by_name(vm_hash[:name])
    return nil unless store
    vmobj = VmOrTemplate.find_by_location_and_storage_id(vm_hash[:location], store.id)
  end

  #
  # Relationship methods
  #

  def disconnect_inv
    self.disconnect_ems

    self.classify_with_parent_folder_path(false)

    self.with_relationship_type('ems_metadata') do
      self.remove_all_parents(:of_type => ['EmsFolder', 'ResourcePool'])
    end

    self.disconnect_host
  end

  def connect_ems(e)
    unless self.ext_management_system == e
      $log.debug "MIQ(#{self.class.name}#connect_ems) Connecting Vm [#{self.name}] id [#{self.id}] to EMS [#{e.name}] id [#{e.id}]"
      self.ext_management_system = e
      self.save
    end
  end

  def disconnect_ems(e=nil)
    if e.nil? || self.ext_management_system == e
      log_text = " from EMS [#{self.ext_management_system.name}] id [#{self.ext_management_system.id}]" unless self.ext_management_system.nil?
      $log.info "MIQ(#{self.class.name}#disconnect_ems) Disconnecting Vm [#{self.name}] id [#{self.id}]#{log_text}"

      self.ext_management_system = nil
      self.raw_power_state = "unknown"
      self.save
    end
  end

  def connect_host(h)
    unless self.host == h
      $log.debug "MIQ(#{self.class.name}#connect_host) Connecting Vm [#{self.name}] id [#{self.id}] to Host [#{h.name}] id [#{h.id}]"
      self.host = h
      self.save

      # Also connect any nics to their lans
      self.connect_lans(h.lans)
    end
  end

  def disconnect_host(h=nil)
    if h.nil? || self.host == h
      log_text = " from Host [#{self.host.name}] id [#{self.host.id}]" unless self.host.nil?
      $log.info "MIQ(#{self.class.name}#disconnect_host) Disconnecting Vm [#{self.name}] id [#{self.id}]#{log_text}"

      self.host = nil
      self.save

      # Also disconnect any nics from their lans
      self.disconnect_lans
    end
  end

  def connect_lans(lans)
    unless lans.blank? || self.hardware.nil?
      self.hardware.nics.each do |n|
        # TODO: Use a different field here
        #   model is temporarily being used here to transfer the name of the
        #   lan to which this nic is connected.  If model ends up being an
        #   otherwise used field, this will need to change
        n.lan = lans.find { |l| l.name == n.model }
        n.model = nil
        n.save
      end
    end
  end

  def disconnect_lans
    unless self.hardware.nil?
      self.hardware.nics.each do |n|
        n.lan = nil
        n.save
      end
    end
  end

  def connect_storage(s)
    unless self.storage == s
      $log.debug "MIQ(Vm-connect_storage) Connecting Vm [#{self.name}] id [#{self.id}] to #{ui_lookup(:table => "storages")} [#{s.name}] id [#{s.id}]"
      self.storage = s
      self.save
    end
  end

  def disconnect_storage(s=nil)
    if s.nil? || self.storage == s || self.storages.include?(s)
      stores = s.nil? ? ([self.storage] + self.storages).compact.uniq : [s]
      log_text = stores.collect {|x| "#{ui_lookup(:table => "storages")} [#{x.name}] id [#{x.id}]"}.join(", ")
      $log.info "MIQ(Vm-disconnect_storage) Disconnecting Vm [#{self.name}] id [#{self.id}] from #{log_text}"

      if s.nil?
        self.storage = nil
        self.storages = []
      else
        self.storage = nil if self.storage == s
        self.storages.delete(s)
      end

      self.save
    end
  end

  # Parent rp, folder and dc methods
  # TODO: Replace all with ancestors lookup once multiple parents is sorted out
  def parent_resource_pool
    self.with_relationship_type('ems_metadata') do
      self.parents(:of_type => "ResourcePool").first
    end
  end
  alias owning_resource_pool parent_resource_pool

  def parent_blue_folder
    return self.with_relationship_type('ems_metadata') do
      self.parents(:of_type => "EmsFolder").first
    end
  end
  alias owning_blue_folder parent_blue_folder

  def parent_blue_folders(*args)
    f = self.parent_blue_folder
    f.nil? ? [] : f.folder_path_objs(*args)
  end

  def under_blue_folder?(folder)
    return false unless folder.kind_of?(EmsFolder)
    self.parent_blue_folders.any? { |f| f == folder }
  end

  def parent_blue_folder_path
    f = self.parent_blue_folder
    f.nil? ? "" : f.folder_path
  end
  alias owning_blue_folder_path parent_blue_folder_path

  def parent_folder
    self.ems_cluster.try(:parent_folder)
  end
  alias owning_folder parent_folder
  alias parent_yellow_folder parent_folder

  def parent_folders(*args)
    f = self.parent_folder
    f.nil? ? [] : f.folder_path_objs(*args)
  end
  alias parent_yellow_folders parent_folders

  def parent_folder_path
    f = self.parent_folder
    f.nil? ? "" : f.folder_path
  end
  alias owning_folder_path parent_folder_path
  alias parent_yellow_folder_path parent_folder_path

  def parent_datacenter
    self.ems_cluster.try(:parent_datacenter)
  end
  alias owning_datacenter parent_datacenter

  def lans
    !self.hardware.nil? ? self.hardware.nics.collect(&:lan).compact : []
  end

  # Create a hash of this Vm's EMS and Host and their credentials
  def ems_host_list
    params = {}
    [self.ext_management_system, "ems", self.host, "host"].each_slice(2) do |ems, type|
      if ems
        params[type] = {
          :address    => ems.address,
          :hostname   => ems.hostname,
          :ipaddress  => ems.ipaddress,
          :username   => ems.authentication_userid,
          :password   => ems.authentication_password_encrypted,
          :class_name => ems.class.name
        }
        params[type][:port] = ems.port if ems.respond_to?(:port) && !ems.port.blank?
      end
    end
    return params
  end

  def reconnect_events
    events = EmsEvent.where("(vm_location = ? AND vm_or_template_id IS NULL) OR (dest_vm_location = ? AND dest_vm_or_template_id IS NULL)", self.path, self.path)
    events.each do |e|
      do_save = false

      src_vm = e.src_vm_or_template
      if src_vm.nil? && e.vm_location == self.path
        src_vm = self
        e.vm_or_template_id = src_vm.id
        do_save = true
      end

      dest_vm = e.dest_vm_or_template
      if dest_vm.nil? && e.dest_vm_location == self.path
        dest_vm = self
        e.dest_vm_or_template_id = dest_vm.id
        do_save = true
      end

      e.save if do_save

      # Hook up genealogy after a Clone Task
      src_vm.add_genealogy_child(dest_vm) if src_vm && dest_vm && e.event_type == EmsEvent::CLONE_TASK_COMPLETE
    end

    return true
  end

  def set_genealogy_parent(parent)
    self.with_relationship_type('genealogy') do
      self.parent = parent
    end
  end

  def add_genealogy_child(child)
    self.with_relationship_type('genealogy') do
      self.set_child(child)
    end
  end

  def myhost
    return @surrogate_host if @surrogate_host
    return self.host unless self.host.nil?

    return self.class.proxy_host_for_repository_scans
  end

  DEFAULT_SCAN_VIA_HOST = true
  cache_with_timeout(:scan_via_host?, 30.seconds) do
    via_host = VMDB::Config.new("vmdb").config.fetch_path(:coresident_miqproxy, :scan_via_host)
    via_host = DEFAULT_SCAN_VIA_HOST unless (via_host.class == TrueClass) || (via_host.class == FalseClass)
    via_host
  end

  def self.scan_via_ems?
    !self.scan_via_host?
  end

  def scan_via_ems?
    self.class.scan_via_ems?
  end

  # Cache the proxy host for repository scans because the JobProxyDispatch calls this for each Vm scan job in a loop
  cache_with_timeout(:proxy_host_for_repository_scans, 30.seconds) do
    defaultsmartproxy = VMDB::Config.new("vmdb").config.fetch_path(:repository_scanning, :defaultsmartproxy)

    proxy = nil
    proxy = MiqProxy.find_by_id(defaultsmartproxy.to_i) if defaultsmartproxy
    proxy ? proxy.host : nil
  end

  def my_zone
    ems = self.ext_management_system
    ems ? ems.my_zone : MiqServer.my_zone
  end

  def my_zone_obj
    Zone.find_by_name(self.my_zone)
  end

  #
  # Proxy methods
  #

  # TODO: Come back to this
  def proxies4job(job=nil)
    proxies = []
    msg = 'Perform SmartState Analysis on this VM'
    embedded_msg = nil

    # If we do not get passed an model object assume it is a job guid
    if job && !job.kind_of?(ActiveRecord::Base)
      jobid = job
      job = Job.find_by_guid(jobid)
    end

    all_proxy_list = self.storage2proxies
    proxies += self.storage2active_proxies(all_proxy_list)

    # If we detect that a MiqServer was in the all_proxies list advise that then host need credentials to use it.
    if all_proxy_list.any? {|p| (MiqServer === p && p.state == "on")}
      embedded_msg = "Provide credentials for this VM's Host to perform SmartState Analysis"
    end

    if proxies.empty?
      msg = embedded_msg.nil? ? 'No active SmartProxies found to analyze this VM' : embedded_msg
    else
      # Work around for the inability to scan running VMs from a host other than the registered host.
      proxies.delete_if {|p| Host === p && p != self.host} if self.scan_on_registered_host_only?

      # If the proxy list is now empty it is because we had to remove all but the registered host above
      if proxies.empty?
        if embedded_msg
          # If we detect that a MiqServer was in the all_proxies list advise that then host need credentials to use it.
          msg = "Start a SmartProxy or provide credentials for this VM's Host to perform SmartState Analysis"
        else
          msg = 'SmartState Analysis is only available through the registered Host for running VM'
        end
      end
    end

    self.log_proxies(proxies, all_proxy_list, msg, job) if proxies.empty? && job

    return {:proxies => proxies.flatten, :message => msg}
  end

  def log_proxies(proxy_list=[], all_proxy_list = nil, message=nil, job=nil)
    begin
      log_method = proxy_list.empty? ? :warn : :debug
      all_proxy_list ||= self.storage2proxies
      proxies = all_proxy_list.collect {|a| "[#{log_proxies_format_instance(a.miq_proxy)}]"}
      job_guid = job.nil? ? "" : job.guid
      proxies_text = proxies.empty? ? "[none]" : proxies.join(" -- ")
      method_name = caller[0][/`([^']*)'/, 1]
      $log.send(log_method, "JOB([#{job_guid}] #{method_name}) Proxies for #{log_proxies_vm_config} : #{proxies_text}")
      $log.send(log_method, "JOB([#{job_guid}] #{method_name}) Proxies message: #{message}") if message
    rescue
    end
  end

  def log_proxies_vm_config
    "[#{log_proxies_format_instance(self)}] on host [#{log_proxies_format_instance(self.host)}] #{ui_lookup(:table => "storages").downcase} [#{self.storage.name}-#{self.storage.store_type}]"
  end

  def log_proxies_format_instance(object)
    return 'Nil' if object.nil?
    return "#{object.class.name}:#{object.id}-#{object.name}:#{object.state}"
  end

  def storage2hosts
    hosts = []
    if self.host.nil?
      store = self.storage
      hosts = store.hosts if hosts.empty? && store
      hosts = [self.myhost] if hosts.empty?
    else
      store = self.storage
      hosts = store.hosts.to_a if hosts.empty? && store
      hosts = [self.myhost] if hosts.empty?

      # VMware needs a VMware host to resolve datastore names
      if self.vendor == 'VMware'
        hosts.delete_if {|h| h.vmm_vendor != 'VMware'}
      end
    end

    return hosts
  end

  def storage2proxies
    @storage_proxies ||= begin
      # Support vixDisk scanning of VMware VMs from the vmdb server
      self.miq_server_proxies
    end
  end

  def storage2active_proxies(all_proxy_list = nil)
    all_proxy_list ||= self.storage2proxies
    proxies = all_proxy_list.select(&:is_proxy_active?)

    # MiqServer coresident proxy needs to contact the host and provide credentials.
    # Remove any MiqServer instances if we do not have credentials
    rsc = self.scan_via_ems? ? self.ext_management_system : self.host
    proxies.delete_if {|p| MiqServer === p} if rsc && !rsc.authentication_status_ok?

    return proxies
  end

  def has_active_proxy?
    self.storage2active_proxies.empty? ? false : true
  end

  def has_proxy?
    self.storage2proxies.empty? ? false : true
  end

  def miq_proxies
    miqproxies = self.storage2proxies.collect(&:miq_proxy).compact

    # The UI does not handle getting back non-MiqProxy objects back from this call.
    # Remove MiqServer elements until we can support different class types.
    miqproxies.delete_if {|p| p.class == MiqServer}
  end

  # Cache the servers because the JobProxyDispatch calls this for each Vm scan job in a loop
  cache_with_timeout(:miq_servers_for_scan, 30.seconds) do
    MiqServer.where(:status => "started").includes([:zone, :server_roles]).to_a
  end

  def miq_server_proxies
    case vm_vendor = self.vendor.to_s
    when 'VMware'
      # VM cannot be scanned by server if they are on a repository
      return [] if self.storage_id.blank? || self.repository_vm?
    when 'RedHat'
      return [] if self.storage_id.blank?
    else
      return []
    end

    host_server_ids = host ? host.vm_scan_affinity.collect(&:id) : []
    storage_server_ids = storages.collect { |s| s.vm_scan_affinity.collect(&:id) }.reject(&:blank?)
    all_storage_server_ids = storage_server_ids.inject(:&) || []
    miq_servers = self.class.miq_servers_for_scan.select do |svr|
      (svr.vm_scan_host_affinity? ? host_server_ids.detect { |id| id == svr.id } : host_server_ids.empty?) &&
      (svr.vm_scan_storage_affinity? ? all_storage_server_ids.detect { |id| id == svr.id } : storage_server_ids.empty?)
    end

    miq_servers.select do |svr|
      result = svr.status == "started" && svr.has_zone?(self.my_zone)
      result = result && svr.is_vix_disk? if vm_vendor == 'VMware'
      # RedHat VMs must be scanned from an EVM server who's host is attached to the same
      # storage as the VM unless overridden via SmartProxy affinity
      if vm_vendor == 'RedHat' && !svr.vm_scan_host_affinity? && !svr.vm_scan_storage_affinity?
        svr_vm = svr.vm
        if svr_vm && svr_vm.host
          missing_storage_ids = storages.collect(&:id) - svr_vm.host.storages.collect(&:id)
          result = result && missing_storage_ids.empty?
        else
          result = false
        end
      end
      result
    end
  end

  def active_proxy_error_message
    return self.proxies4job[:message]
  end

  # TODO: Vmware specific
  def repository_vm?
    self.host.nil?
  end

  # TODO: Vmware specfic
  def template=(val)
    return val unless val ^ self.template # Only continue if toggling setting
    write_attribute(:template, val)

    self.type = self.corresponding_model.name if (self.template? && self.kind_of?(Vm)) || (!self.template? && self.kind_of?(MiqTemplate))
    d = self.template? ? [/\.vmx$/, ".vmtx", 'never'] : [/\.vmtx$/, ".vmx", self.state == 'never' ? 'unknown' : self.raw_power_state]
    self.location = self.location.sub(d[0], d[1]) unless self.location.nil?
    self.raw_power_state = d[2]
  end

  # TODO: Vmware specfic
  def runnable?
    return !self.host.nil? && self.current_state != "never"
  end

  # TODO: Vmware specfic
  def is_controllable?
    return false if !self.runnable? || self.template? || !self.host.control_supported?
    return true
  end

  def self.refresh_ems(vm_ids)
    vm_ids = [vm_ids] unless vm_ids.kind_of?(Array)
    vm_ids = vm_ids.collect { |id| [base_class, id] }
    EmsRefresh.queue_refresh(vm_ids)
  end

  def refresh_ems
    raise "No #{ui_lookup(:table => "ext_management_systems")} defined" unless self.ext_management_system
    raise "No #{ui_lookup(:table => "ext_management_systems")} credentials defined" unless self.ext_management_system.has_credentials?
    raise "#{ui_lookup(:table => "ext_management_systems")} failed last authentication check" unless self.ext_management_system.authentication_status_ok?
    EmsRefresh.queue_refresh(self)
  end

  def self.refresh_ems_sync(vm_ids)
    vm_ids = [vm_ids] unless vm_ids.kind_of?(Array)
    vm_ids = vm_ids.collect { |id| [Vm, id] }
    EmsRefresh.refresh(vm_ids)
  end

  def refresh_ems_sync
    raise "No #{ui_lookup(:table => "ext_management_systems")} defined" unless self.ext_management_system
    raise "No #{ui_lookup(:table => "ext_management_systems")} credentials defined" unless self.ext_management_system.has_credentials?
    raise "#{ui_lookup(:table => "ext_management_systems")} failed last authentication check" unless self.ext_management_system.authentication_status_ok?
    EmsRefresh.refresh(self)
  end

  def refresh_on_reconfig
    raise "No #{ui_lookup(:table => "ext_management_systems")} defined" unless self.ext_management_system
    raise "No #{ui_lookup(:table => "ext_management_systems")} credentials defined" unless self.ext_management_system.has_credentials?
    raise "#{ui_lookup(:table => "ext_management_systems")} failed last authentication check" unless self.ext_management_system.authentication_status_ok?
    EmsRefresh.reconfig_refresh(self)
  end

  def self.post_refresh_ems(ems_id, update_start_time)
    update_start_time = update_start_time.utc
    ems = ExtManagementSystem.find(ems_id)

    # Collect the newly added VMs
    added_vms = ems.vms_and_templates.where("created_on >= ?", update_start_time)

    # Create queue items to do additional process like apply tags and link events
    unless added_vms.empty?
      added_vm_ids = []
      added_vms.each do |v|
        v.post_create_actions_queue
        added_vm_ids << v.id
      end

      self.assign_ems_created_on_queue(added_vm_ids) if VMDB::Config.new("vmdb").config.fetch_path(:ems_refresh, :capture_vm_created_on_date)
    end

    # Collect the updated folder relationships to determine which vms need updated path information
    ems_folders = ems.ems_folders
    MiqPreloader.preload(ems_folders, :all_relationships)

    updated_folders = ems_folders.select do |f|
      f.created_on >= update_start_time || f.updated_on >= update_start_time ||      # Has the folder itself changed (e.g. renamed)?
        f.relationships.any? do |r|                                                  # Or has its relationship rows changed?
          r.created_at >= update_start_time || r.updated_at >= update_start_time ||  #   Has the direct relationship changed (e.g. this folder moved under another folder)?
            r.children.any? do |child_r|                                             #   Or have any of the child relationship rows changed (e.g. vm moved under this folder)?
              child_r.created_at >= update_start_time || child_r.updated_at >= update_start_time
            end
        end
    end
    unless updated_folders.empty?
      updated_vms = updated_folders.collect(&:all_vms_and_templates).flatten.uniq - added_vms
      updated_vms.each(&:classify_with_parent_folder_path_queue)
    end
  end

  def self.assign_ems_created_on_queue(vm_ids)
    MiqQueue.put(
      :class_name  => self.name,
      :method_name => 'assign_ems_created_on',
      :args        => [vm_ids],
      :priority    => MiqQueue::MIN_PRIORITY
    )
  end

  def self.assign_ems_created_on(vm_ids)
    vms_to_update = VmOrTemplate.find_all_by_id_and_ems_created_on(vm_ids, nil)
    return if vms_to_update.empty?

    # Of the VMs without a VM create time, filter out the ones for which we
    #   already have a VM create event
    vms_to_update.reject! do |v|
      #TODO: Vmware specific (fix with event rework?)
      event = v.ems_events.detect {|e| e.event_type == 'VmCreatedEvent'}
      v.update_attribute(:ems_created_on, event.timestamp) if event && v.ems_created_on != event.timestamp
      event
    end
    return if vms_to_update.empty?

    # Of the VMs still without an VM create time, use historical events, if
    #   available, to determine the VM create time
    ems = vms_to_update.first.ext_management_system
    #TODO: Vmware specific
    return unless ems && ems.kind_of?(EmsVmware)

    vms_list = vms_to_update.collect { |v| {:id => v.id, :name => v.name, :uid_ems => v.uid_ems} }
    found = ems.find_vm_create_events(vms_list)

    # Loop through the found VM's and set their create times
    found.each do |vmh|
      v = vms_to_update.detect { |v| v.id == vmh[:id] }
      v.update_attribute(:ems_created_on, vmh[:created_time])
    end
  end

  def post_create_actions_queue
    MiqQueue.put(
      :class_name  => self.class.name,
      :instance_id => self.id,
      :method_name => 'post_create_actions'
    )
  end

  def post_create_actions
    reconnect_events
    classify_with_parent_folder_path
    raise_created_event
  end

  def raise_created_event
    raise NotImplementedError, "raise_created_event must be implemented in a subclass"
  end

  # TODO: Vmware specific
  # Determines the full path from the Storage and location
  def path
    # If Storage id is blank return the location stored for the vm after removing the uri data
    # Otherwise build the path from the storage data and vm location.
    return self.location if storage_id.blank?
    # Return location if it contains a fully-qualified file URI
    return self.location if self.location.starts_with?('file://')
    # Return location for RHEV-M VMs
    return rhevm_config_path if self.vendor.to_s == 'RedHat'

    case self.storage.store_type
    when "VMFS" then "[#{storage.name}] #{location}"
    when "VSAN" then "[#{storage.name}] #{location}"
    when "NFS"  then "[#{storage.name}] #{location}"
    when "NAS"  then File.join(storage.name, location)
    else
      $log.warn("MIQ(Vm-path) VM [#{self.name}] storage type [#{self.storage.store_type}] not supported")
      @path = location
    end
  end

  def rhevm_config_path
    # /rhev/data-center/<datacenter_id>/mastersd/master/vms/<vm_guid>/<vm_guid>.ovf/
    datacenter = self.parent_datacenter
    return self.location if datacenter.blank?
    File.join('/rhev/data-center', datacenter.uid_ems, 'mastersd/master/vms', self.uid_ems, self.location)
  end

  # TODO: Vmware specific
  # Parses a full path into the Storage and location
  def self.parse_path(path)
    #TODO: Review the name of this method such that the return types don't conflict with those of Repository.parse_path
    storage_name, relative_path, type = Repository.parse_path(path)

    storage = Storage.find_by_name(storage_name)
    if storage.nil?
      storage_id = nil
      location   = location2uri(relative_path)
    else
      storage_id = storage.id
      location   = relative_path
    end

    return storage_id, location
  end

  # TODO: Vmware specific
  # Finds a Vm by a full path of the Storage and location
  def self.find_by_path(path)
    begin
      storage_id, location = parse_path(path)
    rescue
      $log.warn "MIQ(#{self.class.name}.find_by_path) Invalid path specified [#{path}]"
      return nil
    end
    VmOrTemplate.find_by_storage_id_and_location(storage_id, location)
  end

  def state
    (power_state || "unknown").downcase
  end
  alias_method :current_state, :state

  # Override raw_power_state= attribute setter in order to impose side effects
  # of setting previous_state and updating state_changed_on
  def raw_power_state=(new_state)
    return unless new_state

    unless raw_power_state == new_state
      self.previous_state   = raw_power_state
      self.state_changed_on = Time.now.utc
      super
      self.power_state      = calculate_power_state
    end
    new_state
  end

  def self.calculate_power_state(raw_power_state)
    (raw_power_state == "never") ? "never" : "unknown"
  end

  def archived?
    self.ext_management_system.nil? && self.storage.nil?
  end
  alias archived archived?

  def orphaned?
    self.ext_management_system.nil? && !self.storage.nil?
  end
  alias orphaned orphaned?

  def active?
    !(archived? || orphaned? || self.retired? || self.template?)
  end
  alias active active?

  def disconnected?
    self.connection_state != "connected"
  end
  alias disconnected disconnected?

  def normalized_state
    %w{archived orphaned template retired disconnected}.each do |s|
      return s if self.send("#{s}?")
    end
    return self.power_state.downcase unless self.power_state.nil?
    return "unknown"
  end

  def ems_cluster_name
    self.ems_cluster.nil? ? nil : self.ems_cluster.name
  end

  def host_name
    self.host.nil? ? nil : self.host.name
  end

  def storage_name
    self.storage.nil? ? nil : self.storage.name
  end

  def has_compliance_policies?
    _, plist = MiqPolicy.get_policies_for_target(self, "compliance", "vm_compliance_check")
    !plist.blank?
  end

  def classify_with_parent_folder_path_queue(add = true)
    MiqQueue.put(
      :class_name  => self.class.name,
      :instance_id => self.id,
      :method_name => 'classify_with_parent_folder_path',
      :args        => [add],
      :priority    => MiqQueue::MIN_PRIORITY
    )
  end

  def classify_with_parent_folder_path(add = true)
    [:blue, :yellow].each do |folder_type|
      path = self.send("parent_#{folder_type}_folder_path")
      next if path.blank?

      cat = self.class.folder_category(folder_type)
      ent = self.class.folder_entry(path, cat)

      $log.info("MIQ(Vm-classify_with_parent_folder_path) #{add ? "C" : "Unc"}lassifying VM: [#{self.name}] with Category: [#{cat.name} => #{cat.description}], Entry: [#{ent.name} => #{ent.description}]")
      ent.send(add ? :assign_entry_to : :remove_entry_from, self, false)
    end
  end

  def self.folder_category(folder_type)
    cat_name = "folder_path_#{folder_type}"
    cat = Classification.find_by_name(cat_name)
    unless cat
      cat = Classification.new(
        :name         => cat_name,
        :description  => "Parent Folder Path (#{folder_type == :blue ? "VMs & Templates" : "Hosts & Clusters"})",
        :parent_id    => 0,
        :single_value => true,
        :read_only    => true
      )
      cat.save(:validate => false)
    end
    return cat
  end

  def self.folder_entry(ent_desc, cat)
    ent_name = ent_desc.downcase.gsub(" ", "_").split("/").join(":")
    ent = cat.find_entry_by_name(ent_name)
    unless ent
      ent = cat.children.new(:name => ent_name, :description => ent_desc)
      ent.save(:validate => false)
    end
    return ent
  end

  def event_where_clause(assoc=:ems_events)
    case assoc.to_sym
    when :ems_events
      return ["vm_or_template_id = ? OR dest_vm_or_template_id = ? ", self.id, self.id]
    when :policy_events
      return ["target_id = ? and target_class = ? ", self.id, self.class.base_class.name]
    end
  end

  # Virtual columns for owning resource pool, folder and datacenter
  def v_owning_cluster
    o = owning_cluster
    return o ? o.name : ""
  end

  def v_owning_resource_pool
    o = owning_resource_pool
    return o ? o.name : ""
  end

  def v_owning_folder
    o = owning_folder
    return o ? o.name : ""
  end

  alias v_owning_folder_path owning_folder_path

  def v_owning_blue_folder
    o = owning_blue_folder
    return o ? o.name : ""
  end

  alias v_owning_blue_folder_path owning_blue_folder_path

  def v_owning_datacenter
    o = owning_datacenter
    return o ? o.name : ""
  end

  def v_is_a_template
    return self.template?.to_s.capitalize
  end

  def v_pct_free_disk_space
    # Verify we have the required data to calculate
    return nil unless self.hardware
    return nil if self.hardware.disk_free_space.nil? || self.hardware.disk_capacity.nil? || self.hardware.disk_free_space.zero? || self.hardware.disk_capacity.zero?

    # Calculate the percentage of free space
    # Call sprintf to ensure xxx.xx formating other decimal length can be too long
    sprintf("%.2f", self.hardware.disk_free_space.to_f / self.hardware.disk_capacity.to_f * 100).to_f
  end

  def v_pct_used_disk_space
    percent_free = self.v_pct_free_disk_space
    return nil unless percent_free
    return 100 - percent_free
  end

  def v_datastore_path
    s = self.storage
    datastorepath = self.location || ""
    datastorepath = "#{s.name}/#{datastorepath}"  unless s.nil?
    return datastorepath
  end

  def v_host_vmm_product
    return self.host ? self.host.vmm_product : nil
  end

  def miq_provision_template
    self.miq_provision ? self.miq_provision.vm_template : nil
  end

  def event_threshold?(options = {:time_threshold => 30.minutes, :event_types => ["MigrateVM_Task_Complete"], :freq_threshold => 2})
    raise "option :event_types is required"    unless options[:event_types]
    raise "option :time_threshold is required" unless options[:time_threshold]
    raise "option :freq_threshold is required" unless options[:freq_threshold]
    conditions = ["(vm_or_template_id = ? OR dest_vm_or_template_id = ?) and event_type in (?) and timestamp >= ?", self.id, self.id,  options[:event_types], options[:time_threshold].to_i.seconds.ago.utc]
    count = EmsEvent.count(:conditions => conditions)
    count >= options[:freq_threshold].to_i
  end

  def reconfigured_hardware_value?(options)
    log_header = "MIQ(#{self.class.name}##{__method__})"

    attr = options[:hdw_attr]
    raise ":hdw_attr required" if attr.nil?

    operator = options[:operator] || ">"
    operator = operator.downcase == "increased" ? ">" : operator.downcase == "decreased" ? "<" : operator

    current_state, prev_state = self.drift_states.order("timestamp DESC").limit(2).all
    if current_state.nil? || prev_state.nil?
      $log.info("#{log_header} Unable to evaluate, not enough state data available")
      return false
    end

    current_value  = current_state.data_obj.hardware.send(attr).to_i
    previous_value = prev_state.data_obj.hardware.send(attr).to_i
    result         = current_value.send(operator, previous_value)
    $log.info("#{log_header} Evaluate: (Current: #{current_value} #{operator} Previous: #{previous_value}) = #{result}")

    result
  end

  def changed_vm_value?(options)
    attr = options[:attr] || options[:hdw_attr]
    raise ":attr required" if attr.nil?

    operator = options[:operator]

    data0, data1 = self.drift_states.order("timestamp DESC").limit(2).all

    if data0.nil? || data1.nil?
      $log.info("MIQ(Vm-changed_vm_value?) Unable to evaluate, not enough state data available")
      return false
    end

    v0 = data0.data_obj.send(attr) || ""
    v1 = data1.data_obj.send(attr) || ""
    if operator.downcase == "changed"
      result = !(v0 == v1)
    else
      raise "operator '#{operator}' is not supported"
    end
    $log.info("MIQ(Vm-changed_vm_value?) Evaluate: !(#{v1} == #{v0}) = #{result}")

    return result
  end

  #
  # Hardware Disks/Memory storage methods
  #

  def disk_storage(col)
    return nil if self.hardware.nil? || self.hardware.disks.blank?
    return self.hardware.disks.inject(0) do |t, d|
      val = d.send(col)
      t + (val.nil? ? d.size.to_i : val.to_i)
    end
  end
  protected :disk_storage

  def allocated_disk_storage
    return self.disk_storage(:size)
  end

  def used_disk_storage
    return self.disk_storage(:size_on_disk)
  end

  def provisioned_storage
    return self.allocated_disk_storage.to_i + self.ram_size_in_bytes
  end

  def used_storage(include_ram = true, check_state = false)
    return self.used_disk_storage.to_i + (include_ram ? self.ram_size_in_bytes(check_state) : 0)
  end

  def used_storage_by_state(include_ram = true)
    return self.used_storage(include_ram, true)
  end

  def uncommitted_storage
    return self.provisioned_storage.to_i - self.used_storage_by_state.to_i
  end

  def thin_provisioned
    return self.hardware.nil? ? false : self.hardware.disks.any? {|d| d.disk_type == 'thin'}
  end

  def ram_size(check_state = false)
    return self.hardware.nil? || (check_state && self.state != 'on') ? 0 : self.hardware.memory_cpu
  end

  def ram_size_by_state
    self.ram_size(true)
  end

  def ram_size_in_bytes(check_state = false)
    return self.ram_size(check_state).to_i * 1.megabyte
  end

  def ram_size_in_bytes_by_state
    return self.ram_size_in_bytes(true)
  end

  alias mem_cpu ram_size

  def num_cpu
    return self.hardware.nil? ? 0 : self.hardware.numvcpus
  end

  def logical_cpus
    return self.hardware.nil? ? 0 : self.hardware.logical_cpus
  end

  def cores_per_socket
    return self.hardware.nil? ? 0 : self.hardware.cores_per_socket
  end

  def num_disks
    return self.hardware.nil? ? 0 : self.hardware.disks.size
  end

  def num_hard_disks
    return self.hardware.nil? ? 0 : self.hardware.hard_disks.size
  end

  def has_rdm_disk
    return false if self.hardware.nil?

    !self.hardware.disks.detect(&:rdm_disk?).nil?
  end

  def disks_aligned
    dlist = self.hardware ? self.hardware.hard_disks : []
    dlist = dlist.reject(&:rdm_disk?) # Skip RDM disks
    return "Unknown" if dlist.empty?
    return "True"    if dlist.all? {|d| d.partitions_aligned == "True"}
    return "False"   if dlist.any? {|d| d.partitions_aligned == "False"}
    return "Unknown"
  end

  def memory_exceeds_current_host_headroom
    return false if self.host.nil?
    (self.ram_size > self.host.current_memory_headroom)
  end

  def collect_running_processes(options={})
    OsProcess.add_elements(self, self.running_processes)
    self.operating_system.save unless self.operating_system.nil?
  end

  def ipaddresses
    return self.hardware.nil? ? [] : self.hardware.ipaddresses
  end

  def hostnames
    return self.hardware.nil? ? [] : self.hardware.hostnames
  end

  def mac_addresses
    return self.hardware.nil? ? [] : self.hardware.mac_addresses
  end

  def hard_disk_storages
    return self.hardware.nil? ? [] : self.hardware.hard_disk_storages
  end

  def processes
    return self.operating_system.nil? ? [] : self.operating_system.processes
  end

  def event_logs
    return self.operating_system.nil? ? [] : self.operating_system.event_logs
  end

  def base_storage_extents
    return self.miq_cim_instance.nil? ? [] : self.miq_cim_instance.base_storage_extents
  end

  def base_storage_extents_size
    return self.miq_cim_instance.nil? ? 0 : self.miq_cim_instance.base_storage_extents_size
  end

  def storage_systems
    return self.miq_cim_instance.nil? ? [] : self.miq_cim_instance.storage_systems
  end

  def storage_systems_size
    return self.miq_cim_instance.nil? ? 0 : self.miq_cim_instance.storage_systems_size
  end

  def storage_volumes
    return self.miq_cim_instance.nil? ? [] : self.miq_cim_instance.storage_volumes
  end

  def storage_volumes_size
    return self.miq_cim_instance.nil? ? 0 : self.miq_cim_instance.storage_volumes_size
  end

  def file_shares
    return self.miq_cim_instance.nil? ? [] : self.miq_cim_instance.file_shares
  end

  def file_shares_size
    return self.miq_cim_instance.nil? ? 0 : self.miq_cim_instance.file_shares_size
  end

  def logical_disks
    return self.miq_cim_instance.nil? ? [] : self.miq_cim_instance.logical_disks
  end

  def logical_disks_size
    return self.miq_cim_instance.nil? ? 0 : self.miq_cim_instance.logical_disks_size
  end

  def direct_service
    self.direct_services.first
  end

  def service
    self.direct_service.try(:root_service)
  end

  #
  # UI Button Validation Methods
  #

  # The UI calls this method to determine if a feature is supported for this VM
  # and determines if a button should be displayed.  This method should return
  # false is the feature is not supported.  This method should return true
  # even if a function is not 'currently' available due to some condition that
  # is not being met.
  #
  # For example: If the VM needs credentials to be scanning, but they are not
  # available this method should still return true.  The UI will call the method
  # 'is_available_now_error_message' to determine if the button should be available
  # or greyed-out.  However, if the VM is a type that we cannot scan or we cannot get
  # to the storage to scan it then this method would be expected to return false.
  def is_available?(request_type)
    return self.send("validate_#{request_type}")[:available]
  end

  # Returns an error message string if there is an error.  Otherwise nil to
  # indicate no errors.
  def is_available_now_error_message(request_type)
    return self.send("validate_#{request_type}")[:message]
  end

  def raise_is_available_now_error_message(request_type)
    msg = self.send("validate_#{request_type}")[:message]
    raise MiqException::MiqVmError, msg unless msg.nil?
  end

  def has_required_host?
    !self.host.nil?
  end

  def has_active_ems?
    # If the VM does not have EMS connection see if it is using SmartProxy as the EMS
    return true unless self.ext_management_system.nil?
    return true if self.host && self.host.acts_as_ems? && self.host.is_proxy_active?
    return false
  end

  #
  # Metric methods
  #

  PERF_ROLLUP_CHILDREN = nil

  def perf_rollup_parent(interval_name=nil)
    self.host unless interval_name == 'realtime'
  end

  # Called from integrate ws to kick off scan for vdi VMs
  def self.vms_by_ipaddress(ipaddress)
    ipaddresses = ipaddress.split(',')
    Network.where("ipaddress in (?)", ipaddresses).each do |network|
      begin
        vm = network.hardware.vm
        yield(vm)
      rescue
      end
    end
  end

  def self.scan_by_property(property, value, options={})
    log_header = "MIQ(#{self.name}.scan_vm_by_property)"
    $log.info "#{log_header} scan_vm_by_property called with property:[#{property}] value:[#{value}]"
    case property
    when "ipaddress"
      vms_by_ipaddress(value) do |vm|
        if vm.state == "on"
          $log.info "#{log_header} Initiating VM scan for [#{vm.id}:#{vm.name}]"
          vm.scan
        end
      end
    else
      raise "Unsupported property type [#{property}]"
    end
  end

  def self.event_by_property(property, value, event_type, event_message, event_time=nil, options={})
    $log.info "MIQ(#{self.name}.event_by_property) event_vm_by_property called with property:[#{property}] value:[#{value}] type:[#{event_type}] message:[#{event_message}] event_time:[#{event_time}]"
    event_timestamp = event_time.blank? ? Time.now.utc : event_time.to_time(:utc)

    case property
    when "ipaddress"
      vms_by_ipaddress(value) do |vm|
        vm.add_ems_event(event_type, event_message, event_timestamp)
      end
    when "uid_ems"
      vm = VmOrTemplate.find_by_uid_ems(value)
      unless vm.nil?
        vm.add_ems_event(event_type, event_message, event_timestamp)
      end
    else
      raise "Unsupported property type [#{property}]"
    end
  end

  def add_ems_event(event_type, event_message, event_timestamp)

    event = {
      :event_type        => event_type,
      :is_task           => false,
      :source            => 'EVM',
      :message           => event_message,
      :timestamp         => event_timestamp,
      :vm_or_template_id => self.id,
      :vm_name           => self.name,
      :vm_location       => self.path,
    }
    event[:ems_id] = self.ems_id unless self.ems_id.nil?

    unless self.host_id.nil?
      event[:host_id]   = self.host_id
      event[:host_name] = self.host.name
    end

    EmsEvent.add(self.ems_id, event)
  end

  def console_supported?(_type)
    false
  end

  # Return all archived VMs
  ARCHIVED_CONDITIONS = "ems_id IS NULL AND storage_id IS NULL"
  def self.all_archived
    self.where(ARCHIVED_CONDITIONS).to_a
  end

  # Return all orphaned VMs
  ORPHANED_CONDITIONS = "ems_id IS NULL AND storage_id IS NOT NULL"
  def self.all_orphaned
    self.where(ORPHANED_CONDITIONS).to_a
  end

  # Stop certain charts from showing unless the subclass allows
  def non_generic_charts_available?
    false
  end
  alias cpu_ready_available?    non_generic_charts_available?
  alias cpu_mhz_available?      non_generic_charts_available?
  alias cpu_percent_available?  non_generic_charts_available?
  alias memory_mb_available?    non_generic_charts_available?

  def self.includes_template?(ids)
    MiqTemplate.where(:id => ids).exists?
  end

  def self.cloneable?(ids)
    vms = VmOrTemplate.where(:id => ids)
    return false if vms.blank?
    vms.all?(&:cloneable?)
  end

  def cloneable?
    false
  end

  def supports_snapshots?
    false
  end

  private

  def power_state=(new_power_state)
    super
  end

  def calculate_power_state
    self.class.calculate_power_state(raw_power_state)
  end
end
