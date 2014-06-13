require 'cim_profile_defs'

class SniaFileShare < MiqCimInstance
  include ReportableMixin
  acts_as_miq_taggable

  virtual_column    :element_name,        :type => :string
  virtual_column    :name,            :type => :string
  virtual_column    :caption,         :type => :string
  virtual_column    :operational_status,    :type => :numeric_set
  virtual_column    :operational_status_str,  :type => :string
  virtual_column    :zone_name,         :type => :string,   :uses => :zone
  virtual_column    :sharing_directory?,    :type => :boolean
  virtual_column    :instance_id,       :type => :string
  virtual_column    :evm_display_name,      :type => :string

  virtual_column    :base_storage_extents_size, :type => :integer
  virtual_column    :cim_datastores_size,   :type => :integer
  virtual_column    :storages_size,       :type => :integer
  virtual_column    :cim_virtual_disks_size,  :type => :integer
  virtual_column    :cim_vms_size,        :type => :integer
  virtual_column    :vms_size,          :type => :integer
  virtual_column    :cim_hosts_size,      :type => :integer
  virtual_column    :hosts_size,        :type => :integer

  virtual_has_one   :file_system,       :class_name => 'SniaLocalFileSystem'
  virtual_has_one   :logical_disk,        :class_name => 'CimLogicalDisk'
  virtual_has_many  :base_storage_extents,    :class_name => 'CimStorageExtent'

  virtual_has_many  :cim_datastores,      :class_name => 'MiqCimDatastore'
  virtual_has_many  :storages,          :class_name => 'Storage'
  virtual_has_many  :cim_virtual_disks,     :class_name => 'MiqCimVirtualDisk'
  virtual_has_many  :cim_vms,         :class_name => 'MiqCimVirtualMachine'
  virtual_has_many  :vms,           :class_name => 'Vm'
  virtual_has_many  :hosts,           :class_name => 'Host'
  virtual_belongs_to  :storage_system,      :class_name => 'CimComputerSystem'

  MODEL_SUBCLASSES  = [ 'OntapFileShare' ]

  FileShareToBaseSe       = CimProfiles.file_share_to_base_storage_extent
  FileShareToVirtualDisk      = CimProfiles.file_share_to_virtual_disk
  FileShareToVm         = CimProfiles.file_share_to_virtual_machine
  FileShareToHost         = CimProfiles.file_share_to_host
  FileShareToLfs          = CimAssociations.CIM_FileShare_TO_SNIA_LocalFileSystem
  FileShareToDatastore      = CimAssociations.CIM_FileShare_TO_MIQ_CimDatastore
  FileShareToStorageSystem    = CimAssociations.CIM_FileShare_TO_CIM_ComputerSystem

  FileShareToLogicalDiskShortcut  = CimAssociations.SNIA_FileShare_TO_CIM_LogicalDisk_SC
  FileShareToBaseSeShortcut   = CimAssociations.SNIA_FileShare_TO_CIM_StorageExtent_SC
  FileShareToVirtualDiskShortcut  = CimAssociations.SNIA_FileShare_TO_MIQ_CimVirtualDisk_SC
  FileShareToVmShortcut     = CimAssociations.SNIA_FileShare_TO_MIQ_CimVirtualMachine_SC
  FileShareToHostShortcut     = CimAssociations.SNIA_FileShare_TO_MIQ_CimHostSystem_SC

  SHORTCUT_DEFS = {
    :base_storage_extents_long  => FileShareToBaseSeShortcut,
    :cim_virtual_disks_long   => FileShareToVirtualDiskShortcut,
    :cim_vms_long       => FileShareToVmShortcut,
    :cim_hosts_long       => FileShareToHostShortcut
  }

  ##########################
  # Filesystem associations
  ##########################

  #
  # No shortcut needed, direct association.
  #
  def local_file_system
    getAssociators(FileShareToLfs).first
  end

  # Old name - should change
  def file_system
    local_file_system
  end

  ############################
  # Logical disk associations
  ############################

  #
  # Association created by CimLogicalDisk class.
  #
  def logical_disk
    getAssociators(FileShareToLogicalDiskShortcut).first
  end

  #####################################################
  # Base Storage Extent (primordial disk) associations
  #####################################################

  def base_storage_extents_long
    dh = {}
    getLeafNodes(FileShareToBaseSe, self, dh)
    dh.values.compact.uniq
  end

  def base_storage_extents
    getAssociators(FileShareToBaseSeShortcut)
  end

  def base_storage_extents_size
    getAssociationSize(FileShareToBaseSeShortcut)
  end

  #########################
  # Datastore associations
  #########################

  #
  # No shortcut needed, direct association.
  #
  def cim_datastores
    getAssociators(FileShareToDatastore)
  end

  def cim_datastores_size
    getAssociationSize(FileShareToDatastore)
  end

  def storages
    getAssociatedVmdbObjs(FileShareToDatastore)
  end

  def storages_size
    getAssociationSize(FileShareToDatastore)
  end

  ##############################
  # Storage system associations
  ##############################

  #
  # No shortcut needed, direct association.
  #
  def storage_system
    getAssociators(FileShareToStorageSystem).first
  end

  ############################
  # Virtual disk associations
  ############################

  def cim_virtual_disks_long
    dh = {}
    getLeafNodes(FileShareToVirtualDisk, self, dh)
    dh.values.compact.uniq.delete_if { |ae| ae.class_name != "MIQ_CimVirtualDisk" }
  end

  def cim_virtual_disks
    getAssociators(FileShareToVirtualDiskShortcut)
  end

  def cim_virtual_disks_size
    getAssociationSize(FileShareToVirtualDiskShortcut)
  end

  ##################
  # VM associations
  ##################

  def cim_vms_long
    dh = {}
    getLeafNodes(FileShareToVm, self, dh)
    dh.values.compact.uniq.delete_if { |ae| ae.class_name != "MIQ_CimVirtualMachine" }
  end

  def cim_vms
    getAssociators(FileShareToVmShortcut)
  end

  def cim_vms_size
    getAssociationSize(FileShareToVmShortcut)
  end

  def vms
    getAssociatedVmdbObjs(FileShareToVmShortcut)
  end

  def vms_size
    getAssociationSize(FileShareToVmShortcut)
  end

  ####################
  # Host associations
  ####################

  def cim_hosts_long
    dh = {}
    getLeafNodes(FileShareToHost, self, dh)
    dh.values.compact.uniq.delete_if { |ae| ae.class_name != "MIQ_CimHostSystem" }
  end

  def cim_hosts
    getAssociators(FileShareToHostShortcut)
  end

  def cim_hosts_size
    getAssociationSize(FileShareToHostShortcut)
  end

  def hosts
    getAssociatedVmdbObjs(FileShareToHostShortcut)
  end

  def hosts_size
    getAssociationSize(FileShareToHostShortcut)
  end

  ###################
  # End associations
  ###################

  def evm_display_name
    instance_id
  end

  def zone_name
    self.zone.nil? ? '' : self.zone.name
  end

  def element_name
    property('ElementName')
  end

  def name
    property('Name')
  end

  def caption
    property('Caption')
  end

  def operational_status
    property('OperationalStatus')
  end

  def operational_status_str
    operational_status_to_str(operational_status)
  end

  def sharing_directory?
    property('SharingDirectory')
  end

  def instance_id
    property('InstanceID')
  end

  def vm_count
    vms.count
  end

  def host_count
    hosts.count
  end

  def storage_count
    storages.count
  end

  def applicable_hosts
    Host.all(:select   => "name, id").inject({}) {|h, host| h[host.id] = host.name; h}
  end

  def queue_create_datastore(ds_name, hosts)
    log_prefix         = "MIQ(#{self.class.name}.queue_create_datastore)"

    unless /^[a-zA-Z0-9\-]+$/ =~ ds_name
      message          = "#{ds_name} is not valid"
      $log.error("#{log_prefix} #{message}")
      self.errors.add("name", message)
      return false
    end

    storage_system  = self.storage_system
    nrs       = storage_system.storage_managers.first
    if nrs.nil?
      message   = "No available manager entry for NetApp filer: #{self.evm_display_name}"
      $log.error("#{log_prefix} #{message}")
      self.errors.add("netapp_filer", message)
      return false
    end

    MiqQueue.put(
      :class_name      => self.class.name,
      :instance_id     => self.id,
      :method_name     => 'create_datastore',
      :args            => [ds_name, hosts],
      :role            => 'ems_operations',
      :zone            => self.zone.name
    )
    return true
  end

  def default_datastore_name
    dname              = self.name.split("/").last
    return if dname.nil?

    dname.tr('_', '-')
  end

  def create_datastore(ds_name, hosts)
    # Returns: Array of true || false, If false, object will have errors attached

    log_prefix         = "MIQ(#{self.class.name}.create_datastore)"
    $log.info("#{log_prefix} Create Datastore: #{name} ...")

    hosts              = hosts.to_miq_a
    nfs_path           = self.name
    local_path         = ds_name || self.default_datastore_name
    access_mode        = "readWrite"

    storage_system     = self.storage_system
    nrs                = storage_system.storage_managers.first
    raise "Could not find manager entry for NetApp filer: #{self.evm_display_name}" if nrs.nil?

    $log.info("#{log_prefix} Found service entry for NetApp filer: #{self.evm_display_name} -> #{nrs.ipaddress}")

    # Add the ESX hosts to the root hosts list for the NFS share.
    $log.info("#{log_prefix} Adding the following to the root hosts list for #{nfs_path}: [ #{hosts.join(', ')} ]")
    nrs.nfs_add_root_hosts(nfs_path, hosts.collect(&:hostname))

    # Get a list of the storage system's IP addresses. Multi-homed systems will have more than one.
    addresses          = nrs.get_addresses
    $log.info("#{log_prefix} Addresses: #{addresses.join(', ')}")

    # For each host, attach the share as a datastore.
    hosts.each do |host|
      # Get the EMS that manages the host.
      if (hems         = host.ext_management_system).nil?
        $log.error("#{log_prefix} Host: #{host.hostname} is not connected to an EMS, skipping")
        next
      end

      # Connect to the EMS.
      $log.info("#{log_prefix} Connecting to EMS #{hems.hostname}...")
      begin
        vim            = hems.connect
      rescue Exception => verr
        $log.error("#{log_prefix} Could not connect to ems - #{hems.hostname}, skipping")
        next
      end

      # Get the VIM object for the host.
      begin
        miqHost        = vim.getVimHost(host.hostname)
        $log.info("#{log_prefix} Got object for host: #{miqHost.name}")
      rescue           => err
        $log.error("#{log_prefix} Could not find host: #{host.hostname}, skipping")
        next
      end

      # Get the datastore system interface for the host.
      miqDss           = miqHost.datastoreSystem

      $log.info("#{log_prefix} Creating datastore: #{local_path} on host: #{host.hostname}...")

      # Given that most Filers will be multihomed, we need to select an address that's
      # accessible by the host in question. Target hosts can be multihomed as well, making
      # IP selection even more complex.
      #
      # The simplest solution may be to try each of the filer's IPs, stopping when
      # createNasDatastore() succeeds.
      addresses.each do |address|
        begin
          $log.info("#{log_prefix} Trying address: #{address}...")
          miqDss.createNasDatastore(address, nfs_path, local_path, access_mode)
        rescue
          $log.info("#{log_prefix} Failed.")
          next
        end
        $log.info("#{log_prefix} Success.")
        break
      end

      miqHost.release
      $log.info("#{log_prefix} Create Datastore: #{name} ... Complete")

      vim.disconnect
    end

    # Queue up EMS refresh for all hosts to ensure that the new datastore is added to VMDB
    host_ids = hosts.collect { |id| [Host, id] }
    EmsRefresh.queue_refresh(host_ids)
  end

end

# Preload any subclasses of this class, so that they will be part of the
# conditions that are generated on queries against this class.
SniaFileShare::MODEL_SUBCLASSES.each { |sc| require_dependency File.join(Rails.root, 'app', 'models', sc.underscore + '.rb')}

