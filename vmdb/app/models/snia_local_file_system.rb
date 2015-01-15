require 'cim_profile_defs'

class SniaLocalFileSystem < MiqCimInstance
  include ReportableMixin
  acts_as_miq_taggable

  virtual_column    :zone_name,           :type => :string,   :uses => :zone
  virtual_column    :name,              :type => :string
  virtual_column    :caption,           :type => :string
  virtual_column    :operational_status,      :type => :numeric_set
  virtual_column    :operational_status_str,    :type => :string
  virtual_column    :root,              :type => :string
  virtual_column    :cs_name,           :type => :string
  virtual_column    :file_system_type,        :type => :string
  virtual_column    :path_name_separator_string,  :type => :string
  virtual_column    :resize_increment,        :type => :integer
  virtual_column    :cluster_size,          :type => :integer
  virtual_column    :block_size,          :type => :integer
  virtual_column    :file_system_size,        :type => :integer
  virtual_column    :available_space,       :type => :integer
  virtual_column    :max_file_name_length,      :type => :integer
  virtual_column    :read_only?,          :type => :boolean
  virtual_column    :case_sensitive?,       :type => :boolean
  virtual_column    :case_preserved?,       :type => :boolean
  virtual_column    :evm_display_name,        :type => :string

  virtual_column    :cim_vms_size,          :type => :integer
  virtual_column    :vm_size,           :type => :integer
  virtual_column    :cim_hosts_size,        :type => :integer
  virtual_column    :host_size,           :type => :integer
  virtual_column    :cim_datastores_size,     :type => :integer
  virtual_column    :storage_size,          :type => :integer

  virtual_has_one   :logical_disk,          :class_name => 'CimLogicalDisk'
  virtual_has_many  :base_storage_extents,      :class_name => 'CimStorageExtent'

  virtual_has_many  :file_shares,         :class_name => 'SniaFileShare'
  virtual_has_many  :cim_datastores,        :class_name => 'MiqCimDatastore'
  virtual_has_many  :storages,            :class_name => 'Storage'
  virtual_has_many  :cim_virtual_disks,       :class_name => 'MiqCimVirtualDisk'
  virtual_has_many  :cim_vms,           :class_name => 'MiqCimVirtualMachine'
  virtual_has_many  :vms,             :class_name => 'Vm'
  virtual_has_many  :hosts,             :class_name => 'Host'
  virtual_belongs_to  :storage_system,        :class_name => 'CimComputerSystem'

  LfsToLogicalDisk      = CimAssociations.SNIA_LocalFileSystem_TO_CIM_StorageExtent
  LfsToFileShare        = CimAssociations.SNIA_LocalFileSystem_TO_CIM_FileShare

  LfsToDatastoreShortcut    = CimAssociations.SNIA_LocalFileSystem_TO_MIQ_CimDatastore_SC
  LfsToVirtualMachineShortcut = CimAssociations.SNIA_LocalFileSystem_TO_MIQ_VirtualMachine_SC
  LfsToHostShortcut     = CimAssociations.SNIA_LocalFileSystem_TO_MIQ_CimHostSystem_SC

  #
  # Downstream ladder.
  #

  def logical_disk
    getAssociators(LfsToLogicalDisk).first
  end

  def base_storage_extents
    logical_disk ? logical_disk.base_storage_extents : []
  end

  #
  # Upstream ladder.
  #

  def file_shares
    getAssociators(LfsToFileShare)
  end

  #########################
  # Datastore associations
  #########################

  #
  # Association created by MiqCimDatastore class.
  #
  def cim_datastores
    getAssociators(LfsToDatastoreShortcut)
  end

  def cim_datastores_size
    getAssociationSize(LfsToDatastoreShortcut)
  end

  def storages
    getAssociatedVmdbObjs(LfsToDatastoreShortcut)
  end

  def storages_size
    getAssociationSize(LfsToDatastoreShortcut)
  end

  def cim_virtual_disks
    cim_datastores.collect(&:cim_virtual_disks).flatten.compact.uniq
  end

  ##################
  # VM associations
  ##################

  #
  # Association created by MiqCimVirtualMachine class.
  #
  def cim_vms
    getAssociators(LfsToVirtualMachineShortcut)
  end

  def cim_vms_size
    getAssociationSize(LfsToVirtualMachineShortcut)
  end

  def vms
    getAssociatedVmdbObjs(LfsToVirtualMachineShortcut)
  end

  def vms_size
    getAssociationSize(LfsToVirtualMachineShortcut)
  end

  ####################
  # Host associations
  ####################

  #
  # Association created by MiqCimVHostSystem class.
  #
  def cim_hosts
    getAssociators(LfsToHostShortcut)
  end

  def cim_hosts_size
    getAssociationSize(LfsToHostShortcut)
  end

  def hosts
    getAssociatedVmdbObjs(LfsToHostShortcut)
  end

  def hosts_size
    getAssociationSize(LfsToHostShortcut)
  end

  def storage_system
    logical_disk.storage_system if logical_disk
  end

  def evm_display_name
    @evmDisplayName ||= begin
      if storage_system.nil?
        root
      else
        storage_system.evm_display_name + ":" + root
      end
    end
  end

  def zone_name
    self.zone.nil? ? '' : self.zone.name
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

  def file_system_type
    property('FileSystemType')
  end

  def cs_name
    property('CSName')
  end

  def root
    property('Root')
  end

  def resize_increment
    property('ResizeIncrement')
  end

  def cluster_size
    property('ClusterSize')
  end

  def file_system_size
    property('FileSystemSize')
  end

  def block_size
    property('BlockSize')
  end

  def available_space
    property('AvailableSpace')
  end

  def max_file_name_length
    property('MaxFileNameLength')
  end

  def path_name_separator_string
    property('PathNameSeparatorString')
  end

  def persistence_type
    property('PersistenceType')
  end

  def read_only?
    property('ReadOnly')
  end

  def case_sensitive?
    property('CaseSensitive')
  end

  def case_preserved?
    property('CasePreserved')
  end

end
