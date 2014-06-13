require 'cim_profile_defs'

class CimStorageExtent < MiqCimInstance
  include ReportableMixin
  acts_as_miq_taggable

  virtual_column    :description,       :type => :string
  virtual_column    :caption,         :type => :string
  virtual_column    :health_state,        :type => :integer
  virtual_column    :health_state_str,      :type => :string
  virtual_column    :operational_status,    :type => :numeric_set
  virtual_column    :operational_status_str,  :type => :string
  virtual_column    :zone_name,         :type => :string,   :uses => :zone
  virtual_column    :enabled_state,       :type => :integer
  virtual_column    :system_name,       :type => :string
  virtual_column    :number_of_blocks,      :type => :integer
  virtual_column    :block_size,        :type => :integer
  virtual_column    :consumable_blocks,     :type => :integer
  virtual_column    :device_id,         :type => :string
  virtual_column    :extent_status,       :type => :numeric_set
  virtual_column    :primordial?,       :type => :boolean
  virtual_column    :evm_display_name,      :type => :string

  virtual_column    :cim_vms_size,        :type => :integer
  virtual_column    :vms_size,          :type => :integer
  virtual_column    :cim_hosts_size,      :type => :integer
  virtual_column    :hosts_size,        :type => :integer
  virtual_column    :cim_datastores_size,   :type => :integer
  virtual_column    :storages_size,       :type => :integer

  virtual_has_many  :base_storage_extents,    :class_name => 'MiqCimInstance'

  virtual_has_many  :top_storage_extents,   :class_name => 'CimStorageExtent'
  virtual_has_many  :storage_volumes,     :class_name => 'CimStorageVolume'
  virtual_has_many  :logical_disks,       :class_name => 'CimLogicalDisk'
  virtual_has_many  :file_systems,        :class_name => 'SniaLocalFileSystem'
  virtual_has_many  :file_shares,       :class_name => 'SniaFileShare'
  virtual_has_many  :cim_datastores,      :class_name => 'CimStorageExtent'
  virtual_has_many  :storages,          :class_name => 'Storage'
  virtual_has_many  :cim_vms,         :class_name => 'MiqCimVirtualMachine'
  virtual_has_many  :vms,           :class_name => 'VmOrTemplate'
  virtual_has_many  :hosts,           :class_name => 'Host'
  virtual_belongs_to  :storage_system,      :class_name => 'CimComputerSystem'

  MODEL_SUBCLASSES  = [
    'CimLogicalDisk',
    'CimStorageVolume',
    'OntapConcreteExtent',
    'OntapFlexVolExtent',
    'OntapPlexExtent',
    'OntapRaidGroupExtent'
  ]

  SeToBaseSe          = CimProfiles.storage_extent_to_base_storage_extent
  SeToTopSe         = CimProfiles.base_storage_extent_to_top_storage_extent
  SeToStorageSystem     = CimAssociations.CIM_StorageExtent_TO_CIM_ComputerSystem

  BseToDatastoreShortcut    = CimAssociations.CIM_StorageExtent_TO_MIQ_CimDatastore_SC
  BseToHostShortcut     = CimAssociations.CIM_StorageExtent_TO_MIQ_CimHostSystem_SC
  BseToVirtualMachineShortcut = CimAssociations.CIM_StorageExtent_TO_MIQ_CimVirtualMachine_SC

  #
  # Downstream ladder.
  #

  def base_storage_extents
    dh = {}
    getLeafNodes(SeToBaseSe, self, dh)
    dh.values.compact.uniq
  end

  #
  # Upstream ladder.
  #

  def top_storage_extents
    dh = {}
    getLeafNodes(SeToTopSe, self, dh)
    dh.values.delete_if { |ae| !ae.kinda?("CIM_StorageVolume") && !ae.kinda?("CIM_LogicalDisk") }.compact.uniq
  end

  def storage_volumes
    dh = {}
    getLeafNodes(SeToTopSe, self, dh)
    dh.values.delete_if { |ae| !ae.kinda?("CIM_StorageVolume") }.compact.uniq
  end

  def logical_disks
    dh = {}
    getLeafNodes(SeToTopSe, self, dh)
    dh.values.delete_if { |ae| !ae.kinda?("CIM_LogicalDisk") }.compact.uniq
  end

  def file_systems
    logical_disks.collect { |cld| cld.file_system }.compact.uniq
  end

  def file_shares
    file_systems.collect { |cfs| cfs.file_shares }.flatten.compact.uniq
  end

  #########################
  # Datastore associations
  #########################

  #
  # Association created by MiqCimDatastore class.
  #
  def cim_datastores
    getAssociators(BseToDatastoreShortcut)
  end

  def cim_datastores_size
    getAssociationSize(BseToDatastoreShortcut)
  end

  def storages
    getAssociatedVmdbObjs(BseToDatastoreShortcut)
  end

  def storages_size
    getAssociationSize(BseToDatastoreShortcut)
  end

  ##################
  # VM associations
  ##################

  #
  # Association created by MiqCimVirtualMachine class.
  #
  def cim_vms
    getAssociators(BseToVirtualMachineShortcut)
  end

  def cim_vms_size
    getAssociationSize(BseToVirtualMachineShortcut)
  end

  def vms
    getAssociatedVmdbObjs(BseToVirtualMachineShortcut)
  end

  def vms_size
    getAssociationSize(BseToVirtualMachineShortcut)
  end

  ####################
  # Host associations
  ####################

  #
  # Association created by MiqCimHostSystem class.
  #
  def cim_hosts
    getAssociators(BseToHostShortcut)
  end

  def cim_hosts_size
    getAssociationSize(BseToHostShortcut)
  end

  def hosts
    getAssociatedVmdbObjs(BseToHostShortcut)
  end

  def hosts_size
    getAssociationSize(BseToHostShortcut)
  end

  def storage_system
    getAssociators(SeToStorageSystem).first
  end

  def evm_display_name
    @evmDisplayName ||= begin
      if storage_system.nil?
        device_id
      else
        storage_system.evm_display_name + ":" + device_id
      end
    end
  end

  def zone_name
    self.zone.nil? ? '' : self.zone.name
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

  def enabled_state
    property('EnabledState')
  end

  def system_name
    property('SystemName')
  end

  def number_of_blocks
    property('NumberOfBlocks')
  end

  def block_size
    property('BlockSize')
  end

  def consumable_blocks
    property('ConsumableBlocks')
  end

  def device_id
    property('DeviceID')
  end

  def extent_status
    property('ExtentStatus')
  end

  def primordial?
    property('Primordial')
  end

end

# Preload any subclasses of this class, so that they will be part of the
# conditions that are generated on queries against this class.
CimStorageExtent::MODEL_SUBCLASSES.each { |sc| require_dependency File.join(Rails.root, 'app', 'models', sc.underscore + '.rb')}
