class Storage < ActiveRecord::Base
  has_many :repositories
  has_many :vms_and_templates, :foreign_key => :storage_id, :dependent => :nullify, :class_name => "VmOrTemplate"
  has_many :miq_templates,     :foreign_key => :storage_id
  has_many :vms,               :foreign_key => :storage_id
  has_and_belongs_to_many :hosts
  has_and_belongs_to_many :all_vms_and_templates, :class_name => "VmOrTemplate"
  has_and_belongs_to_many :all_miq_templates, :class_name => "MiqTemplate",  :join_table => :storages_vms_and_templates, :association_foreign_key => :vm_or_template_id
  has_and_belongs_to_many :all_vms, :class_name => "Vm", :join_table => :storages_vms_and_templates, :association_foreign_key => :vm_or_template_id
  has_many :disks

  has_many :metrics,        :as => :resource  # Destroy will be handled by purger
  has_many :metric_rollups, :as => :resource  # Destroy will be handled by purger
  has_many :vim_performance_states, :as => :resource  # Destroy will be handled by purger

  has_many :storage_files,       :dependent => :destroy
  has_many :storage_files_files, :class_name => "StorageFile", :foreign_key => "storage_id", :conditions => "rsc_type = 'file'"
  has_many :files,               :class_name => "StorageFile", :foreign_key => "storage_id", :conditions => "rsc_type = 'file'"
  has_many :hosts_storages

  has_one  :miq_cim_instance, :as => :vmdb_obj, :dependent => :destroy

  virtual_has_many  :base_storage_extents, :class_name => "CimStorageExtent"
  virtual_has_many  :storage_systems,      :class_name => "CimComputerSystem"
  virtual_has_one   :file_share,           :class_name => 'SniaFileShare'
  virtual_has_many  :storage_volumes,      :class_name => 'CimStorageVolume'
  virtual_has_one   :logical_disk,         :class_name => 'CimLogicalDisk'

  validates_presence_of     :name
  # We can't uncomment this until the SmartProxy starts sending location when registering VMs
  # validates_uniqueness_of   :location

  include RelationshipMixin

  acts_as_miq_taggable
  include ReportableMixin

  include SerializedEmsRefObjMixin
  include FilterableMixin
  include Metric::CiMixin
  include StorageMixin
  include AsyncDeleteMixin
  include WebServiceAttributeMixin


  virtual_column :v_used_space,                   :type => :integer
  virtual_column :v_used_space_percent_of_total,  :type => :integer
  virtual_column :v_free_space_percent_of_total,  :type => :integer
  virtual_column :v_debris_percent_of_used,       :type => :float,   :uses => :debris_size
  virtual_column :v_disk_percent_of_used,         :type => :float,   :uses => :disk_size
  virtual_column :v_snapshot_percent_of_used,     :type => :float,   :uses => :snapshot_size
  virtual_column :v_memory_percent_of_used,       :type => :float,   :uses => :vm_ram_size
  virtual_column :v_vm_misc_percent_of_used,      :type => :float,   :uses => :vm_misc_size
  virtual_column :v_total_debris_size,            :type => :integer, :uses => :debris_size
  virtual_column :v_total_snapshot_size,          :type => :integer, :uses => :snapshot_size
  virtual_column :v_total_memory_size,            :type => :integer, :uses => :vm_ram_size
  virtual_column :v_total_vm_misc_size,           :type => :integer, :uses => :vm_misc_size
  virtual_column :v_total_hosts,                  :type => :integer
  virtual_column :v_total_vms,                    :type => :integer
  virtual_column :v_total_provisioned,            :type => :integer
  virtual_column :v_provisioned_percent_of_total, :type => :float
  virtual_column :total_managed_unregistered_vms, :type => :integer
  virtual_column :total_managed_registered_vms,   :type => :integer
  virtual_column :total_unmanaged_vms,            :type => :integer  # uses is handled via class method that aggregates
  virtual_column :count_of_vmdk_disk_files,       :type => :integer

  SUPPORTED_STORAGE_TYPES = ["VMFS", "NFS"]

  def miq_proxies
    MiqProxy.find(:all).select { |p| p.storages.include?(self) }
  end

  def to_s
    self.name
  end

  def ext_management_systems
    @ext_management_systems ||= Host.includes(:storages).to_a.select { |h| h.storages.include?(self) }.collect { |h| h.ext_management_system }.compact.uniq
  end

  def ext_management_systems_in_zone(zone_name)
    self.ext_management_systems.select { |ems| ems.my_zone == zone_name }
  end

  def active_hosts_with_credentials_in_zone(zone_name)
    self.active_hosts_with_credentials.select { |h| h.my_zone == zone_name }
  end

  def active_hosts_with_credentials
    self.active_hosts.select { |h| h.authentication_valid? }
  end

  def active_hosts_in_zone(zone_name)
    self.active_hosts.select { |h| h.my_zone == zone_name }
  end

  def active_hosts
    self.hosts.select { |h| h.state == "on" }
  end

  def my_zone
    return MiqServer.my_zone if     self.ext_management_systems.empty?
    return MiqServer.my_zone unless self.ext_management_systems_in_zone(MiqServer.my_zone).empty?
    return self.ext_management_systems.first.my_zone
  end

  def scan_starting(miq_task_id, host)
    log_header = "MIQ(Storage.scan_starting)"

    miq_task = MiqTask.find_by_id(miq_task_id)
    if miq_task.nil?
      $log.warn("#{log_header} MiqTask with ID: [#{miq_task_id}] cannot be found")
      return
    end

    message = "Starting File refresh for Storage [#{self.name}] via Host [#{host.name}]"
    miq_task.update_message(message)
  end

  def scan_complete_callback(miq_task_id, status, message, result)
    log_header = "MIQ(Storage.scan_complete_callback)"
    $log.info "#{log_header} Storage ID: [#{self.id}], MiqTask ID: [#{miq_task_id}], Status: [#{status}]"

    miq_task = MiqTask.find_by_id(miq_task_id)
    if miq_task.nil?
      $log.warn("#{log_header} MiqTask with ID: [#{miq_task_id}] cannot be found")
      return
    end

    miq_task.lock(:exclusive) do |locked_miq_task|
      if locked_miq_task.context_data[:targets].length == 1
        unless MiqTask.status_ok?(status)
          self.task_results = result unless result.nil?
        end
      end

      if MiqTask.status_error?(status)
        locked_miq_task.context_data[:error] ||= []
        locked_miq_task.context_data[:error] << self.id
      end

      if MiqTask.status_timeout?(status)
        locked_miq_task.context_data[:timeout] ||= []
        locked_miq_task.context_data[:timeout] << self.id
      end

      locked_miq_task.context_data[:complete] << self.id
      locked_miq_task.context_data[:pending].delete(self.id)
      locked_miq_task.pct_complete = 100 * locked_miq_task.context_data[:complete].length / locked_miq_task.context_data[:targets].length
      locked_miq_task.save!

      if self.class.scan_complete?(locked_miq_task)
        task_status = MiqTask::STATUS_OK
        task_status = MiqTask::STATUS_TIMEOUT if locked_miq_task.context_data.has_key?(:timeout)
        task_status = MiqTask::STATUS_ERROR   if locked_miq_task.context_data.has_key?(:error)

        locked_miq_task.update_status(MiqTask::STATE_FINISHED, task_status, self.class.scan_complete_message(miq_task))
      else
        self.class.scan_queue(locked_miq_task)
      end
    end
  end

  def scan_queue_item(miq_task_id)
    log_header = "MIQ(Storage.scan_queue_item)"
    MiqEvent.raise_evm_job_event(self, :type => "scan", :prefix => "request")
    $log.info "#{log_header} Queueing SmartState Analysis for Storage ID: [#{self.id}], MiqTask ID: [#{miq_task_id}]"
    cb = { :class_name => self.class.name, :instance_id => self.id, :method_name => :scan_complete_callback, :args => [miq_task_id] }
    MiqQueue.put(
      :class_name   => self.class.name,
      :instance_id  => self.id,
      :method_name  => 'smartstate_analysis',
      :args         => [miq_task_id],
      :msg_timeout  => self.class.scan_collection_timeout,
      :miq_callback => cb,
      :zone         => self.my_zone,
      :role         => 'ems_operations'
    )
  end

  def self.scan_queue(miq_task, queue_limit = 1)
    log_header = "MIQ(Storage.scan_queue)"

    queued = 0
    unprocessed = scan_storages_unprocessed(miq_task)
    loop do
      storage_id = unprocessed.shift
      break if storage_id.nil?

      storage = Storage.find_by_id(storage_id.to_i)
      if storage.nil?
        $log.warn("#{log_header} Storage with ID: [#{storage_id}] cannot be found - removing from target list")
        miq_task.context_data[:targets] = miq_task.context_data[:targets].reject { |sid| sid == storage_id }
        next
      end

      begin
        qitem = storage.scan_queue_item(miq_task.id)
        miq_task.context_data[:pending][storage_id] = qitem.id
        queued += 1
        break if queued >= queue_limit
      rescue => err
        $log.warn("#{log_header} Storage name: [#{storage.name}], id: [#{storage.id}]: rejected for scan because <#{err.message}> - removing from target list")
        miq_task.context_data[:targets] = miq_task.context_data[:targets].reject { |sid| sid == storage_id }
        next
      end
    end
    miq_task.message = scan_update_message(miq_task)
    miq_task.save!
  end

  def self.scan_storages_unprocessed(miq_task)
    miq_task.context_data[:targets] - (miq_task.context_data[:complete] + miq_task.context_data[:pending].keys)
  end

  def self.scan_complete?(miq_task)
    miq_task.context_data[:complete].length == miq_task.context_data[:targets].length
  end

  def self.scan_complete_message(miq_task)
    message = "SmartState Analysis for #{miq_task.context_data[:targets].length} storages complete"
    message += " (#{miq_task.context_data[:error].length} in Error)"    if miq_task.context_data.has_key?(:error)
    message += " (#{miq_task.context_data[:timeout].length} Timed Out)" if miq_task.context_data.has_key?(:timeout)
    message
  end

  def self.scan_update_message(miq_task)
    message  = "#{miq_task.context_data[:pending].length} Storage Scans Pending; #{miq_task.context_data[:complete].length} of #{miq_task.context_data[:targets].length} Scans Complete"
    message += " (#{miq_task.context_data[:error].length} in Error)"    if miq_task.context_data.has_key?(:error)
    message += " (#{miq_task.context_data[:timeout].length} Timed Out)" if miq_task.context_data.has_key?(:timeout)
    message
  end

  def self.scan_collection_timeout
    vmdb_storage_config[:collection] && vmdb_storage_config[:collection][:timeout]
  end

  def self.scan_queue_watchdog(miq_task_id)
    MiqQueue.put(
      :class_name   => self.name,
      :method_name  => 'scan_watchdog',
      :args         => [miq_task_id],
      :zone         => MiqServer.my_zone,
      :deliver_on   => scan_watchdog_deliver_on
    )
  end

  def self.scan_watchdog_deliver_on
    Time.now.utc + scan_watchdog_interval
  end

  def self.scan_watchdog(miq_task_id)
    log_header = "MIQ(Storage.scan_watchdog)"

    miq_task = MiqTask.find_by_id(miq_task_id)
    if miq_task.nil?
      $log.warn("#{log_header} MiqTask with ID: [#{miq_task_id}] cannot be found")
      return
    end

    if scan_complete?(miq_task)
      $log.info "#{log_header} #{scan_complete_message(miq_task)}"
      return
    end

    miq_task.lock(:exclusive) do |locked_miq_task|
      locked_miq_task.context_data[:pending].each do |storage_id, qitem_id|
        qitem = MiqQueue.find_by_id(qitem_id)
        if qitem.nil?
          $log.warn "#{log_header} Pending Scan for Storage ID: [#{storage_id}] is missing MiqQueue ID: [#{qitem_id}] - will requeue"
          locked_miq_task.context_data[:pending].delete(storage_id)
          locked_miq_task.save!
          scan_queue(locked_miq_task)
        end
      end
    end
    scan_queue_watchdog(miq_task.id)
  end

  def self.vmdb_storage_config
    VMDB::Config.new("storage").config
  end

  DEFAULT_WATCHDOG_INTERVAL = 1.minute
  def self.scan_watchdog_interval
    config = vmdb_storage_config
    return DEFAULT_WATCHDOG_INTERVAL if config['watchdog_interval'].nil?
    return config['watchdog_interval'].to_s.to_i_with_method
  end

  DEFAULT_MAX_QITEMS_PER_SCAN_REQUEST = 0
  def self.max_qitems_per_scan_request
    config = vmdb_storage_config
    config['max_qitems_per_scan_request'] || DEFAULT_MAX_QITEMS_PER_SCAN_REQUEST
  end

  DEFAULT_MAX_PARALLEL_SCANS_PER_HOST = 1
  def self.max_parallel_storage_scans_per_host
    config = vmdb_storage_config
    config['max_parallel_scans_per_host'] || DEFAULT_MAX_PARALLEL_SCANS_PER_HOST
  end

  def self.scan_eligible_storages(zone_name = nil)
    log_header = "MIQ(Storage.scan_eligible_storages)"
    zone_caption = zone_name ? " for zone [#{zone_name}]" : ""
    $log.info "#{log_header} Computing#{zone_caption} Started"
    storages = []
    self.find(:all, :conditions => { :store_type => SUPPORTED_STORAGE_TYPES }).each do |storage|
      unless storage.perf_capture_enabled?
        $log.info "#{log_header} Skipping scan of Storage: [#{storage.name}], performance capture is not enabled"
        next
      end

      if zone_name && storage.ext_management_systems_in_zone(zone_name).empty?
        $log.info "#{log_header} Skipping scan of Storage: [#{storage.name}], storage under EMS in a different zone from [#{zone_name}]"
        next
      end

      storages << storage
    end

    $log.info "#{log_header} Computing#{zone_caption} Complete -- Storage IDs: #{storages.collect { |s| s.id }.sort.inspect}"
    storages
  end

  def self.create_scan_task(task_name, userid, storages)
    log_header = "MIQ(Storage.create_scan_task)"
    context_data = { :targets  => storages.collect { |s| s.id }.sort, :complete => [], :pending  => {} }
    miq_task     = MiqTask.create(
                      :name         => task_name,
                      :state        => MiqTask::STATE_QUEUED,
                      :status       => MiqTask::STATUS_OK,
                      :message      => "Task has been queued",
                      :pct_complete => 0,
                      :userid       => userid,
                      :context_data => context_data
                    )

    $log.info "#{log_header} Created MiqTask ID: [#{miq_task.id}], Name: [#{task_name}]"

    max_qitems = max_qitems_per_scan_request
    max_qitems = storages.length unless max_qitems.kind_of?(Numeric) && (max_qitems > 0) # Queue them all (unlimited) unless greater than 0
    miq_task.lock(:exclusive) { |locked_miq_task| scan_queue(locked_miq_task, max_qitems) }
    scan_queue_watchdog(miq_task.id)
    return miq_task
  end

  def self.scan_timer(zone_name = nil)
    log_header = "MIQ(Storage.scan_timer)"
    storages = scan_eligible_storages(zone_name)

    if storages.empty?
      $log.info "#{log_header} No Eligible Storages"
      return nil
    end

    task_name = "SmartState Analysis for All Storages#{zone_name ? " in Zone \"#{zone_name}\"" : ''}"
    create_scan_task(task_name, 'system', storages)
  end

  def scan(userid = "system", role = "ems_operations")
    log_header = "MIQ(Storage.scan)"
    raise(MiqException::MiqUnsupportedStorage, "Action not supported for #{ui_lookup(:table=>"storages")} type [#{self.store_type}], [#{self.name}] with id: [#{self.id}]") unless SUPPORTED_STORAGE_TYPES.include?(self.store_type)

    hosts = self.active_hosts_with_credentials
    raise(MiqException::MiqStorageError,       "Check that a Host is running and has valid credentials for #{ui_lookup(:table=>"storages")} [#{self.name}] with id: [#{self.id}]") if hosts.empty?

    task_name = "SmartState Analysis for [#{self.name}]"
    self.class.create_scan_task(task_name, userid, [self])
  end

  def self.unregistered_vm_config_files
    Storage.find(:all).inject([]) {|list, s| list + s.unregistered_vm_config_files}
  end

  def unmanaged_vm_config_files
    files = if association_cache.include?(:storage_files)
      self.storage_files.select { |f| f.ext_name == "vmx" && f.vm_or_template_id.nil? }
    else
      self.storage_files.all(:conditions => {:ext_name => "vmx", :vm_or_template_id => nil})
    end
    return files.collect {|f| f.name}
  end

  # Cache storage file counts for the entire list of storages so that looping over
  # storages to get total_unmanaged_vms in a report or view is optimized
  cache_with_timeout(:total_unmanaged_vms, 15.seconds) do
    StorageFile.all(
      :select     => "COUNT(id) AS storage_file_count, storage_id",
      :conditions => {:ext_name => "vmx", :vm_or_template_id => nil},
      :group      => :storage_id
    ).each_with_object(Hash.new(0)) { |sf, h| h[sf.storage_id] = sf.storage_file_count.to_i }
  end

  def total_unmanaged_vms
    self.class.total_unmanaged_vms[self.id]
  end

  cache_with_timeout(:count_of_vmdk_disk_files, 15.seconds) do
    flat_clause  = "base_name NOT LIKE '%-flat.vmdk'"
    delta_clause = "base_name NOT LIKE '%-delta.vmdk'"
    snap_clause  = "AND #{ActiveRecordQueryParts.not_regexp("base_name", "%\-[0-9][0-9][0-9][0-9][0-9][0-9]\.vmdk")}"

    StorageFile.all(
      :select     => "COUNT(id) AS storage_file_count, storage_id",
      :conditions => "ext_name = 'vmdk' AND #{flat_clause} AND #{delta_clause} #{snap_clause}",
      :group      => :storage_id
    ).each_with_object(Hash.new(0)) { |sf, h| h[sf.storage_id] = sf.storage_file_count.to_i }
  end

  def count_of_vmdk_disk_files
    self.class.count_of_vmdk_disk_files[self.id]
  end

  def registered_vms
    self.vms.select { |v| v.registered? }
  end

  def unregistered_vms
    self.vms.select { |v| !v.registered? }
  end

  cache_with_timeout(:unmanaged_vm_counts_by_storage_id, 15.seconds) do
    Vm.all(
      :conditions => ["((template = ? AND ems_id IS NOT NULL) OR host_id IS NOT NULL)", true],
      :select     => "COUNT(id) AS vm_count, storage_id",
      :group      => "storage_id"
    ).each_with_object(Hash.new(0)) { |v, h| h[v.storage_id] = v.vm_count.to_i }
  end

  def total_managed_registered_vms
    if association_cache.include?(:vms)
      self.registered_vms.length
    else
      self.class.unmanaged_vm_counts_by_storage_id[self.id]
    end
  end

  cache_with_timeout(:unregistered_vm_counts_by_storage_id, 15.seconds) do
    Vm.all(
      :conditions => ["((template = ? AND ems_id IS NULL) OR host_id IS NOT NULL)", true],
      :select     => "COUNT(id) AS vm_count, storage_id",
      :group      => "storage_id"
    ).each_with_object(Hash.new(0)) { |v, h| h[v.storage_id] = v.vm_count.to_i }
  end

  def total_unregistered_vms
    if association_cache.include?(:vms)
      self.unregistered_vms.length
    else
      self.class.unregistered_vm_counts_by_storage_id[self.id]
    end
  end

  cache_with_timeout(:managed_unregistered_vm_counts_by_storage_id, 15.seconds) do
    Vm.all(
      :conditions => ["((template = ? AND ems_id IS NOT NULL) OR host_id IS NOT NULL)", true],
      :select     => "COUNT(id) AS vm_count, storage_id",
      :group      => "storage_id"
    ).each_with_object(Hash.new(0)) { |v, h| h[v.storage_id] = v.vm_count.to_i }
  end

  def total_managed_unregistered_vms
    if association_cache.include?(:vms)
      self.unregistered_vms.length
    else
      self.class.managed_unregistered_vm_counts_by_storage_id[self.id]
    end
  end

  def unmanaged_vm_ram_size(vms = nil)
    self.add_files_sizes(:unmanaged_vm_ram_files, vms)
  end

  def unmanaged_vm_ram_files(vms = nil)
    self.unmanaged_files_collection(:vm_ram_files, vms)
  end

  def unmanaged_snapshot_size(vms = nil)
    self.add_files_sizes(:unmanaged_snapshot_files, vms)
  end

  def unmanaged_snapshot_files(vms = nil)
    self.unmanaged_files_collection(:snapshot_files, vms)
  end

  def unmanaged_disk_size(vms = nil)
    self.add_files_sizes(:unmanaged_disk_files, vms)
  end

  def unmanaged_disk_files(vms = nil)
    self.unmanaged_files_collection(:disk_files, vms)
  end

  def unmanaged_debris_size(vms = nil)
    self.add_files_sizes(:unmanaged_debris_files, vms)
  end

  def unmanaged_debris_files(vms = nil)
    self.unmanaged_files_collection(:debris_files, vms)
  end

  def unmanaged_files_collection(collection_type, vms = nil)
    match_paths = self.unmanaged_paths(vms)
    self.send(collection_type).select { |f| match_paths.include?(File.dirname(f.name)) }
  end

  def unmanaged_paths(vms = nil)
    vms = unmanaged_vm_config_files if vms.nil?
    vms = vms.to_miq_a
    vms.collect {|f| File.dirname(f)}.compact
  end

  def qmessage?(method_name)
    return false if $_miq_worker_current_msg.nil?
    ($_miq_worker_current_msg.class_name == self.class.name) && ($_miq_worker_current_msg.instance_id = self.id) && ($_miq_worker_current_msg.method_name == method_name)
  end

  def smartstate_analysis_count_for_host_id(host_id)
    MiqQueue.count(
      :conditions => ["class_name = ? AND instance_id = ? AND method_name = ? AND target_id = ? AND state = ?", self.class.name, self.id, "smartstate_analysis", host_id, 'dequeue']
    )
  end

  def smartstate_analysis(miq_task_id=nil)
    method_name = "smartstate_analysis"
    log_header = "MIQ(Storage.#{method_name})"

    unless miq_task_id.nil?
      miq_task = MiqTask.find_by_id(miq_task_id)
      miq_task.state_active unless miq_task.nil?
    end

    hosts = active_hosts_with_credentials_in_zone(MiqServer.my_zone)
    if hosts.empty?
      message = "There are no active Hosts with valid credentials connected to Storage: [#{self.name}] in Zone: [#{MiqServer.my_zone}]."
      $log.warn "#{log_header} #{message}"
      raise MiqException::MiqUnreachableStorage, message
    end

    max_parallel_storage_scans_per_host = self.class.max_parallel_storage_scans_per_host
    host = nil
    hosts.each do |h|
      next if smartstate_analysis_count_for_host_id(h.id) >= max_parallel_storage_scans_per_host
      host = h
      break
    end

    if host.nil?
      raise MiqException::MiqQueueRetryLater.new( { :deliver_on => Time.now.utc + 1.minute } ) if qmessage?(method_name)
      host = hosts.random_element
    end

    $_miq_worker_current_msg.update_attributes!(:target_id => host.id) if qmessage?(method_name)

    st = Time.now
    message = "Storage [#{self.name}] via Host [#{host.name}]"
    $log.info "#{log_header} #{message}...Starting"
    scan_starting(miq_task_id, host)
    if host.respond_to?(:refresh_files_on_datastore)
      host.refresh_files_on_datastore(self)
    else
      $log.warn "#{log_header} #{message}...Not Supported for #{host.class.name}"
    end
    self.update_attribute(:last_scan_on, Time.now.utc)
    $log.info "#{log_header} #{message}...Completed in [#{Time.now - st}] seconds"

    begin
      MiqEvent.raise_evm_job_event(self, :type => "scan", :suffix => "complete")
    rescue => err
      $log.warn("#{log_header} Error raising complete scan event for #{self.class.name} name: [#{self.name}], id: [#{self.id}]: #{err.message}")
    end

    return nil
  end

  def set_unassigned_storage_files_to_vms
    StorageFile.link_storage_files_to_vms(self.storage_files.find_all_by_vm_or_template_id(nil), self.vm_ids_by_path)
  end

  def vm_ids_by_path
    host_ids = self.hosts.collect { |h| h.id }
    return nil if host_ids.empty?
    Vm.find(:all, :conditions => ["host_id IN (?)", host_ids], :include => :storage).inject({}) { |h, v| h[File.dirname(v.path)] = v.id; h }
  end

  # TODO: Is this still needed?
  def self.get_common_refresh_targets(storages)
    storages = storages.to_miq_a
    return [] if storages.empty?
    storages = self.find(storages) unless storages[0].kind_of?(Storage)

    objs = storages.collect do |s|
      # Get the first VM or Host that's available since we can't refresh a storage directly
      obj = s.vms.find(:first, :order => :id)
      obj = s.hosts.find(:first, :order => :id) if obj.nil?
      obj
    end
    return objs.compact.uniq
  end

  def used_space
    return total_space.to_i == 0 ? 0 : total_space.to_i - free_space.to_i
  end
  alias v_used_space used_space

  def used_space_percent_of_total
    return total_space.to_f == 0.0 ? 0.0 : (used_space.to_f / total_space.to_f * 1000.0).round / 10.0
  end
  alias v_used_space_percent_of_total used_space_percent_of_total

  def free_space_percent_of_total
    return total_space.to_f == 0.0 ? 0.0 : (free_space.to_f / total_space.to_f * 1000.0).round / 10.0
  end
  alias v_free_space_percent_of_total free_space_percent_of_total

  def v_total_hosts
    if association_cache.include?(:hosts)
      self.hosts.size
    else
      self.hosts_storages.length
    end
  end

  cache_with_timeout(:vm_counts_by_storage_id, 15.seconds) do
    Vm.all(
      :select => "COUNT(id) AS vm_count, storage_id",
      :group  => "storage_id"
    ).each_with_object(Hash.new(0)) { |v, h| h[v.storage_id] = v.vm_count.to_i }
  end

  def v_total_vms
    if association_cache.include?(:vms)
      self.vms.size
    else
      self.class.vm_counts_by_storage_id[self.id]
    end
  end

  alias v_total_debris_size   debris_size
  alias v_total_snapshot_size snapshot_size
  alias v_total_memory_size   vm_ram_size
  alias v_total_vm_misc_size  vm_misc_size
  alias v_total_disk_size     disk_size

  def v_debris_percent_of_used
    return used_space.to_f == 0.0 ? 0.0 : (debris_size.to_f / used_space.to_f * 1000.0).round / 10.0
  end

  def v_snapshot_percent_of_used
    return used_space.to_f == 0.0 ? 0.0 : (snapshot_size.to_f / used_space.to_f * 1000.0).round / 10.0
  end

  def v_memory_percent_of_used
    return used_space.to_f == 0.0 ? 0.0 : (vm_ram_size.to_f / used_space.to_f * 1000.0).round / 10.0
  end

  def v_vm_misc_percent_of_used
    return used_space.to_f == 0.0 ? 0.0 : (vm_misc_size.to_f / used_space.to_f * 1000.0).round / 10.0
  end

  def v_disk_percent_of_used
    return used_space.to_f == 0.0 ? 0.0 : (disk_size.to_f / used_space.to_f * 1000.0).round / 10.0
  end

  def v_total_provisioned
    self.used_space + self.uncommitted.to_i
  end

  def v_provisioned_percent_of_total
    return total_space.to_f == 0 ? 0.0 : (self.v_total_provisioned.to_f / total_space.to_f * 1000.0).round / 10.0
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

  def file_share
    return self.miq_cim_instance.nil? ? nil : self.miq_cim_instance.file_share
  end

  def logical_disk
    return self.miq_cim_instance.nil? ? [] : self.miq_cim_instance.logical_disk
  end

  def netapp_filer
    self.storage_systems.each do |ss|
      next unless ss.class_name == 'ONTAP_StorageSystem'
      naf = NetAppFiler.find_by_name(ss.element_name)
      return naf unless naf.nil?
    end

    return nil
  end

  #
  # Metric methods
  #

  PERF_ROLLUP_CHILDREN = :ext_management_systems

  def perf_rollup_parent(interval_name=nil)
    MiqRegion.my_region unless interval_name == 'realtime'
  end

  # TODO: See if we can reuse the main perf_capture method, and only overwrite the perf_collect_metrics method
  def perf_capture(interval_name)
    raise ArgumentError, "invalid interval_name '#{interval_name}'" unless Metric::Capture::VALID_CAPTURE_INTERVALS.include?(interval_name)

    log_header = "MIQ(#{self.class.name}.perf_capture) [#{interval_name}]"
    log_target = "#{self.class.name} name: [#{self.name}], id: [#{self.id}]"

    $log.info "#{log_header} Capture for #{log_target}..."

    klass, meth = Metric::Helper.class_and_association_for_interval_name(interval_name)

    dummy, t = Benchmark.realtime_block(:total_time) do
      hour = Metric::Helper.nearest_hourly_timestamp(Time.now.utc + 30.minutes)

      interval = case interval_name
      when "hourly" then 1.hour
      when "daily" then 1.day
      else 0
      end

      Benchmark.realtime_block(:db_find_storage_files) do
        MiqPreloader.preload(self, :vms => :storage_files_files)
      end

      state, = Benchmark.realtime_block(:capture_state) { self.perf_capture_state }

      attrs = nil
      Benchmark.realtime_block(:init_attrs) do
        attrs = {
          :capture_interval                         => interval,
          :resource_name                            => self.name,
          :derived_storage_total                    => self.total_space,
          :derived_storage_free                     => self.free_space,
          :derived_vm_count_on                      => state.vm_count_on,
          :derived_host_count_on                    => state.host_count_on,
          :derived_vm_count_off                     => state.vm_count_off,
          :derived_host_count_off                   => state.host_count_off,
          :assoc_ids                                => state.assoc_ids,
          :tag_names                                => state.tag_names,
          :derived_storage_vm_count_registered      => self.registered_vms.length,
          :derived_storage_vm_count_unregistered    => self.unregistered_vms.length,
          :derived_storage_vm_count_unmanaged       => self.unmanaged_vm_config_files.length,
          :derived_storage_vm_count_managed         => self.registered_vms.length + self.unregistered_vms.length,
          :derived_storage_snapshot_unmanaged       => self.unmanaged_snapshot_size,
          :derived_storage_mem_unmanaged            => self.unmanaged_vm_ram_size,
          :derived_storage_disk_unmanaged           => self.unmanaged_disk_size,
          :derived_storage_used_unmanaged           => 0,
          :derived_storage_used_managed             => 0,
          :derived_vm_used_disk_storage             => 0,
          :derived_vm_allocated_disk_storage        => 0
        }

        # Calculate the amount of storage used for unmanaged vms by adding the snapshots, memory and disk files
        [:derived_storage_snapshot_unmanaged, :derived_storage_mem_unmanaged, :derived_storage_disk_unmanaged].each do |file_type|
          attrs[:derived_storage_used_unmanaged] += attrs[file_type] if attrs[file_type].is_a?(Numeric)
        end
      end

      # Read all the existing perfs for this time range to speed up lookups
      obj_perfs, = Benchmark.realtime_block(:db_find_prev_perfs) do
        Metric::Finders.hash_by_capture_interval_name_and_timestamp(self.vms + [self], hour, hour, interval_name)
      end

      perf = nil
      Benchmark.realtime_block(:process_perfs) do
        vm_attrs = {}

        ['registered', 'unregistered'].each do |mode|
          attrs["derived_storage_used_#{mode}".to_sym] ||= 0

          self.send("#{mode}_vms").each do |vm|
            vm_attrs = {:capture_interval => interval, :resource_name => vm.name}
            vm_attrs[:derived_storage_vm_count_managed] = 1
            vm_attrs["derived_storage_vm_count_#{mode}".to_sym] = 1

            vm_attrs["derived_storage_snapshot_#{mode}".to_sym] = vm.snapshot_size
            vm_attrs["derived_storage_mem_#{mode}".to_sym] = vm.vm_ram_size
            vm_attrs["derived_storage_disk_#{mode}".to_sym] = vm.disk_size

            vm_attrs[:derived_storage_used_managed] = 0

            val = vm.used_disk_storage
            vm_attrs[:derived_vm_used_disk_storage] = val
            attrs[:derived_vm_used_disk_storage]   += val unless val.nil?

            val = vm.allocated_disk_storage
            vm_attrs[:derived_vm_allocated_disk_storage] = val
            attrs[:derived_vm_allocated_disk_storage]   += val unless val.nil?

            ['snapshot', 'mem', 'disk'].each {|a|
              col = "derived_storage_#{a}_#{mode}".to_sym
              val = vm_attrs[col]
              attrs[col] ||= 0
              attrs[col] += val unless val.nil?

              col = "derived_storage_#{a}_managed".to_sym
              attrs[col] ||= 0
              vm_attrs[col] ||= 0

              unless val.nil?
                attrs[col] += val
                attrs["derived_storage_used_#{mode}".to_sym] += val
                attrs[:derived_storage_used_managed] += val
                vm_attrs[col] +=  val
                vm_attrs[:derived_storage_used_managed] += val
              end
            }

            vm_perf   = obj_perfs.fetch_path(vm.class.name, vm.id, interval_name, hour)
            vm_perf ||= obj_perfs.store_path(vm.class.name, vm.id, interval_name, hour, vm.send(meth).build(:timestamp => hour, :capture_interval_name => interval_name))

            vm_attrs.reverse_merge!(vm_perf.attributes)
            vm_attrs.merge!(Metric::Processing.process_derived_columns(vm, vm_attrs))
            vm_perf.update_attributes(vm_attrs)
          end
        end

        perf   = obj_perfs.fetch_path(self.class.name, self.id, interval_name, hour)
        perf ||= obj_perfs.store_path(self.class.name, self.id, interval_name, hour, self.send(meth).build(:timestamp => hour, :capture_interval_name => interval_name))

        perf.update_attributes(attrs)
      end

      Benchmark.realtime_block(:process_perfs_tag) { VimPerformanceTagValue.build_from_performance_record(perf) }

      self.update_attribute(:last_perf_capture_on, hour)
      self.perf_rollup_to_parent(interval_name, hour)
    end

    $log.info "#{log_header} Capture for #{log_target}...Complete - Timings: #{t.inspect}"
  end

  def vm_scan_affinity
    with_relationship_type("vm_scan_storage_affinity") { parents }
  end
end
