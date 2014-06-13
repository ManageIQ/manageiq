require 'cim_profile_defs'

class CimComputerSystem < MiqCimInstance
  include ReportableMixin
  acts_as_miq_taggable

  virtual_column    :element_name,        :type => :string
  virtual_column    :name,            :type => :string
  virtual_column    :description,       :type => :string
  virtual_column    :caption,         :type => :string
  virtual_column    :health_state,        :type => :integer
  virtual_column    :health_state_str,      :type => :string
  virtual_column    :operational_status,    :type => :numeric_set
  virtual_column    :operational_status_str,  :type => :string
  virtual_column    :other_identifying_info,  :type => :string_set
  virtual_column    :zone_name,         :type => :string,   :uses => :zone
  virtual_column    :evm_display_name,      :type => :string

  virtual_column    :vms_size,          :type => :integer
  virtual_column    :hosts_size,        :type => :integer
  virtual_column    :storages_size,       :type => :integer
  virtual_column    :hosted_file_shares_size, :type => :integer
  virtual_column    :local_file_systems_size, :type => :integer
  virtual_column    :storage_volumes_size,    :type => :integer
  virtual_column    :logical_disks_size,    :type => :integer
  virtual_column    :base_storage_extents_size, :type => :integer

  virtual_has_many  :hosted_file_shares,  :class_name => "SniaFileShare"
  virtual_has_many  :local_file_systems,  :class_name => "SniaLocalFileSystem"
  virtual_has_many  :storage_volumes,   :class_name => "CimStorageVolume"
  virtual_has_many  :logical_disks,     :class_name => "CimLogicalDisk"
  virtual_has_many  :base_storage_extents,  :class_name => "CimStorageExtent"
  virtual_has_many  :cim_datastores,    :class_name => 'MiqCimDatastore'
  virtual_has_many  :storages,        :class_name => 'Storage'
  virtual_has_many  :cim_vms,       :class_name => 'MiqCimVirtualMachine'
  virtual_has_many  :vms,         :class_name => 'Vm'
  virtual_has_many  :hosts,         :class_name => 'Host'

  MODEL_SUBCLASSES  = [ 'OntapStorageSystem' ]

  CcsToBse            = CimProfiles.storage_system_to_base_storage_extent
  CcsToVm             = CimProfiles.storage_system_to_virtual_machine
  CcsToDatastores         = CimProfiles.storage_system_to_datastore
  CcsToHosts            = CimProfiles.storage_system_to_host
  CcsToLfs            = CimProfiles.storage_system_to_filesystem
  CcsToStorageVolume        = CimAssociations.CIM_ComputerSystem_TO_CIM_StorageVolume
  CcsToLogicalDisk        = CimAssociations.CIM_ComputerSystem_TO_CIM_LogicalDisk
  CcsToFileShare          = CimAssociations.CIM_ComputerSystem_TO_CIM_FileShare

  CcsToVmShortcut         = CimAssociations.CIM_ComputerSystem_TO_MIQ_CimVirtualMachine_SC
  CcsToHostShortcut       = CimAssociations.CIM_ComputerSystem_TO_MIQ_CimHostSystem_SC
  CcsToDatastoreShortcut      = CimAssociations.CIM_ComputerSystem_TO_MIQ_CimDatastore_SC
  CcsToLocalFileSystemShortcut  = CimAssociations.CIM_ComputerSystem_TO_SNIA_LocalFileSystem_SC
  CcsToBseShortcut        = CimAssociations.CIM_ComputerSystem_TO_CIM_StorageExtent_SC

  SHORTCUT_DEFS = {
    :cim_vms_long       => CcsToVmShortcut,
    :cim_datastores_long    => CcsToDatastoreShortcut,
    :cim_hosts_long       => CcsToHostShortcut,
    :local_file_systems_long  => CcsToLocalFileSystemShortcut,
    :base_storage_extents_long  => CcsToBseShortcut
  }

  ##################
  # VM associations
  ##################

  def cim_vms_long
    dh = {}
    getLeafNodes(CcsToVm, self, dh)
    dh.values.delete_if { |ae| ae.class_name != "MIQ_CimVirtualMachine" }
  end

  def cim_vms
    getAssociators(CcsToVmShortcut)
  end

  def vms
    getAssociatedVmdbObjs(CcsToVmShortcut)
  end

  def vms_size
    getAssociationSize(CcsToVmShortcut)
  end

  ####################
  # Host associations
  ####################

  def cim_hosts_long
    dh = {}
    getLeafNodes(CcsToHosts, self, dh)
    dh.values.delete_if { |ae| ae.class_name != "MIQ_CimHostSystem" }
  end

  def cim_hosts
    getAssociators(CcsToHostShortcut)
  end

  def cim_hosts_size
    getAssociationSize(CcsToHostShortcut)
  end

  def hosts
    getAssociatedVmdbObjs(CcsToHostShortcut)
  end

  def hosts_size
    getAssociationSize(CcsToHostShortcut)
  end

  #########################
  # Datastore associations
  #########################

  def cim_datastores_long
    dh = {}
    getLeafNodes(CcsToDatastores, self, dh)
    dh.values.delete_if { |ae| ae.class_name != "MIQ_CimDatastore" }
  end

  def cim_datastores
    getAssociators(CcsToDatastoreShortcut)
  end

  def cim_datastores_size
    getAssociationSize(CcsToDatastoreShortcut)
  end

  def storages
    getAssociatedVmdbObjs(CcsToDatastoreShortcut)
  end

  def storages_size
    getAssociationSize(CcsToDatastoreShortcut)
  end

  ##########################
  # File Share associations
  ##########################

  #
  # No shortcut needed, direct association.
  #
  def hosted_file_shares
    getAssociators(CcsToFileShare)
  end

  def hosted_file_shares_size
    getAssociationSize(CcsToFileShare)
  end

  ##########################
  # Filesystem associations
  ##########################

  def local_file_systems_long
    dh = {}
    getLeafNodes(CcsToLfs, self, dh)
    return dh.values
  end

  def local_file_systems
    getAssociators(CcsToLocalFileSystemShortcut)
  end

  def local_file_systems_size
    getAssociationSize(CcsToLocalFileSystemShortcut)
  end

  ####################################
  # Storage Volume (LUN) associations
  ####################################

  #
  # No shortcut needed, direct association.
  #
  def storage_volumes
    getAssociators(CcsToStorageVolume)
  end

  def storage_volumes_size
    getAssociationSize(CcsToStorageVolume)
  end

  ############################
  # Logical Disk associations
  ############################

  #
  # No shortcut needed, direct association.
  #
  def logical_disks
    getAssociators(CcsToLogicalDisk)
  end

  def logical_disks_size
    getAssociationSize(CcsToLogicalDisk)
  end

  #####################################################
  # Base Storage Extent (primordial disk) associations
  #####################################################

  def base_storage_extents_long
    dh = {}
    getLeafNodes(CcsToBse, self, dh)
    dh.values
  end

  def base_storage_extents
    getAssociators(CcsToBseShortcut)
  end

  def base_storage_extents_size
    getAssociationSize(CcsToBseShortcut)
  end

  ###################
  # End associations
  ###################

  def protocol_endpoints(resultClass=nil)
    getAssociators( :AssocClass   => 'CIM_HostedAccessPoint',
            :ResultClass  => resultClass,
            :Role     => 'Antecedent',
            :ResultRole   => 'Dependent'
    )
  end

  def zone_name
    self.zone.nil? ? '' : self.zone.name
  end

  def evm_display_name
    element_name
  end

  def element_name
    property('ElementName')
  end

  def name
    property('Name')
  end

  def description
    property('Description')
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

  def health_state
    property('HealthState')
  end

  def health_state_str
    health_state_to_str(health_state)
  end

  def other_identifying_info
    property('OtherIdentifyingInfo')
  end

  def storage_managers
    storageManagers = []
    return storageManagers if self.class_name != "ONTAP_StorageSystem"

    getAssociators( :AssocClass => 'CIM_HostedAccessPoint',
            :Role   => "Antecedent",
            :ResultRole => "Dependent"
    ).each do |ap|
      next if ap.property("CreationClassName") != "ONTAP_RemoteServiceAccessPoint"
      ai = ap.property("AccessInfo")
      next unless (/http:\/\/([^\/]*)\/na_admin/ =~ ai)
      sma = NetappRemoteService.find(:all, :conditions => ["ipaddress = ? or hostname = ?", $1, $1])
      storageManagers.concat(sma) unless sma.length == 0
    end
    return storageManagers
  end

  def available_aggregates
    nrs            = self.storage_managers.first
    return if nrs.nil?

    nrs.aggr_list_info.inject({}) do |h,aggr|
      free_space   = ActionView::Base.new.number_to_human_size(aggr.size_available.to_i, :precision => 2)
      h[aggr.name] = "#{aggr.name} (#{free_space} available)"
      h
    end
  end

  def create_logical_disk(name, aggrName, size, spaceReserve="none")
    # Returns: Array of true || false, If false, object will have errors attached

    log_prefix = "MIQ(#{self.class.name}.create_logical_disk)"
    $log.info("#{log_prefix} Create logical disk: #{name} ...")

    # Get the management inteface for the storage system.
    nrs = self.storage_managers.first
    if nrs.nil?
      field, message = ["NetAppFiler:", "Could not find manager entry: #{self.evm_display_name}"]
      $log.error("#{log_prefix} #{field} #{message}")
      self.errors.add(field, message)
      return false
    end
    $log.info("#{log_prefix} Found service entry for NetApp filer: #{self.evm_display_name} -> #{nrs.ipaddress}")

    # Check to see if the volume already exists.
    if nrs.has_volume?(name)
      field, message = ["LogicalDisk:", "#{name} already exists"]
      $log.error("#{log_prefix} #{field} #{message}")
      self.errors.add(field, message)
      return false
    end
    $log.info("#{log_prefix} Logical Disk  #{name} does not exist, continuing...")

    # Make sure there's enough free space in the aggregate for the new volume.
    $log.info("#{log_prefix} Checking space on containing aggregate: #{aggrName}")
    begin
      aggr_info = nrs.aggr_list_info(aggrName)
    rescue => err
      $log.log_backtrace(err)
      self.errors.add("Aggregate:", err.message)
      return false
    end
    aggr_free_space = aggr_info.size_available.to_i
    if aggr_free_space < size.to_i.gigabytes
      field, message = ["Size:", "Insufficient free space in #{aggrName}: #{aggr_free_space}"]
      $log.error("#{log_prefix} #{field} #{message}")
      self.errors.add(field, message)
      return false
    end
    $log.info("#{log_prefix} Containing aggregate: #{aggrName} has sufficient free space")

    # Create the volume within the given aggregate.
    $log.info("#{log_prefix} Queuing creation of logical disk: #{name} in aggregate: #{aggrName} on NAS server: #{self.evm_display_name}...")
    nrs.queue_volume_create(name, aggrName, "#{size}g")
    $log.info("#{log_prefix} Create logical disk: #{name} ... Complete")

    return true
  end
end

# Preload any subclasses of this class, so that they will be part of the
# conditions that are generated on queries against this class.
CimComputerSystem::MODEL_SUBCLASSES.each { |sc| require_dependency File.join(Rails.root, 'app', 'models', sc.underscore + '.rb')}
