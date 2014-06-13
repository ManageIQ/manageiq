class MiqCimVirtualDisk < MiqCimInstance
  include ReportableMixin

  virtual_has_one   :cim_datastore,     :class_name => 'MiqCimDatastore'
  virtual_has_one   :storage,       :class_name => 'Storage'

  virtual_has_one   :cim_vm,        :class_name => 'MiqCimVirtualMachine'
  virtual_has_one   :vm,          :class_name => 'Vm'
  virtual_has_many  :hosts,         :class_name => 'Host'
  virtual_has_many  :datastore_backing,   :class_name => 'MiqCimInstance'
  virtual_has_many  :storage_systems,   :class_name => 'CimComputerSystem'
  virtual_has_one   :file_share,      :class_name => 'SniaFileShare'
  virtual_has_many  :storage_volumes,   :class_name => 'CimStorageVolume'
  virtual_has_one   :file_system,     :class_name => 'SniaLocalFileSystem'
  virtual_has_one   :logical_disk,      :class_name => 'CimLogicalDisk'
  virtual_has_many  :base_storage_extents,  :class_name => 'CimStorageExtent'

  #
  # Downstream adjacency.
  #
  def cim_datastore
    getAssociators( :AssocClass   => 'MIQ_VirtualDiskDatastore',
            :ResultClass  => 'MIQ_CimDatastore',
            :Role     => 'Antecedent',
            :ResultRole   => 'Dependent'
    ).first
  end

  def storage
    return nil unless (cds = cim_datastore)
    cds.vmdb_obj
  end

  #
  # Upstream adjacency.
  #
  def cim_vm
    getAssociators( :AssocClass   => 'MIQ_VmVirtualDisk',
            :ResultClass  => 'MIQ_CimVirtualMachine',
            :Role     => 'Dependent',
            :ResultRole   => 'Antecedent'
    ).first
  end

  def vm
    cim_vm.vmdb_obj
  end

  def hosts
    return nil unless (s = storage)
    s.hosts
  end

  #
  # Downstream ladder.
  #

  def datastore_backing
    return [] unless (cds = cim_datastore)
    cds.backing
  end

  def storage_systems
    datastore_backing.collect { |cdb| cdb.storage_system }.flatten.compact.uniq
  end

  def file_share
    return nil unless (cds = cim_datastore)
    cds.file_share
  end

  def storage_volumes
    return [] unless (cds = cim_datastore)
    cds.storage_volumes
  end

  def file_system
    return nil unless (fs = file_share)
    fs.file_system
  end

  def logical_disk
    return nil unless (fs = file_system)
    fs.logical_disk
  end

  def base_storage_extents
    datastore_backing.collect { |cdb| cdb.base_storage_extents }.flatten.compact.uniq
  end

end
