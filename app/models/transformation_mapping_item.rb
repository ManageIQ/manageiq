class TransformationMappingItem < ApplicationRecord
  belongs_to :transformation_mapping
  belongs_to :source,      :polymorphic => true
  belongs_to :destination, :polymorphic => true
  # TODO, What is the MIQ wide logging syntax and way
  tmilogger = Rails.logger

  validates :source_id, :uniqueness => {:scope => [:transformation_mapping_id, :source_type]}

  validates :destination_type,
            :inclusion => { :in => %w[EmsCluster CloudTenant Storage Lan CloudVolumeType CloudNetwork] }

  validate :destination_cluster, :if => -> { destination_type.casecmp?('EmsCluster') }
  validate :source_cluster, :if => -> { source_type.casecmp?('EmsCluster') }

  validate :destination_datastore, :if => -> { destination_type.casecmp?('Storage') ||
                                               destination_type.casecmp?('CloudVolumeType')
                                             }

  validate :source_datastore, :if => -> { source_type.casecmp?('Storage') }

  validate :destination_network, :if => -> { source_type.casecmp?('Lan') ||
                                             source_type.casecmp?('CloudNetwork')
                                           }
  validate :source_network,      :if => -> { destination_type.casecmp?('Lan') }

  VALID_SOURCE_CLUSTER_PROVIDERS    = %w[vmwarews]
  VALID_DESTINATION_CLUSTER_TYPES   = %w[EmsCluster CloudTenant]

  VALID_SOURCE_DATASTORE_TYPES      = %w[Storage]
  VALID_DESTINATION_DATASTORE_TYPES = %w[Storage CloudVolumeType]

  VALID_SOURCE_NETWORK_TYPES        = %w[Lan]
  VALID_DESTINATION_NETWORK_TYPES   = %w[Lan CloudNetwork]

  private

  # Validator used if the source type is an EMS cluster. In this case, both
  # the source and target types must be validated.
  #
  # Note that the validation here for the target is more flexible than the
  # target_cluster validator since it allows either an EmsCluster or CloudTenant.
  #
  def source_cluster
    unless VALID_SOURCE_CLUSTER_PROVIDERS.include?(source.ext_management_system.emstype)
      source_types = VALID_SOURCE_CLUSTER_PROVIDERS.join(', ')
      errors.add(:source_type, "EMS type of source cluster must be in: #{source_types}")
    end

    unless VALID_DESTINATION_CLUSTER_TYPES.include?(destination_type)
      destination_types = VALID_DESTINATION_CLUSTER_TYPES.join(', ')
      errors.add(:destination_type, "Class of target cluster must be in: #{destination_types}")
    end
  end # of source_cluster

  # Validator used if the target is an EMS cluster. This is more specific than
  # the source_cluster validation because here it only validates against
  # EmsCluster types.
  #
  def destination_cluster
    unless VALID_DESTINATION_CLUSTER_TYPES.include?(destination.ext_management_system.emstype)
      destination_types = VALID_DESTINATION_CLUSTER_TYPES.join(', ')
      errors.add(:destination_type, "EMS type of target cluster must be in: #{destination_types}")
    end
  end # of destination_cluster

  # How to check the datastore(s) belong to the source.
  #
  def source_datastore
    tmilogger = Rails.logger
    storageClassNames = source.hosts.          # Get hosts using this source storage
        collect { |host| host.ems_cluster }.   # How many clusters does each host has
        collect { |cluster| cluster.storages}. # How many storages each host is mapped to that belong to the cluster
        flatten.collect { |s| s.class.name }   # Get storage types represented by its class name

    tmilogger.info( "#{__method__.to_s} :  #{storageClassNames.to_s}" )

    # check if source storage belongs to cluster storage.
    # the only valid storage type is "Storage"
    if storageClassNames.include?(VALID_SOURCE_DATASTORE_TYPES.first)
      result = true
    else
      storage_types = VALID_SOURCE_DATASTORE_TYPES.join(', ')
      errors.add(:storage_type, "The type of destination type must be in: #{storage_types}")
    end
  end # of source_datastore

  # Check the storage types are valid.
  #
  def destination_datastore
    tmilogger = Rails.logger
    # from irb
    # myds.destination.hosts.collect{ |host| host.ems_cluster }.collect{ |cluster| cluster.storages }.flatten.include?(myds.destination)

    storageClassNames = destination.hosts. # Get hosts using this source storage
    collect { |host| host.ems_cluster }.   # How many clusters does each host has
    collect { |cluster| cluster.storages}. # How many storages each host is mapped to that belong to the cluster
    flatten.collect { |s| s.class.name }   # Get storage types represented by its class name

    logger.info("ARIF ARIF ARIF TEST TEST TEST")
    tmilogger.info( "#{__method__.to_s} :  #{storageClassNames.to_s}" )

    # check if desitination storage belongs to cluster storage.
    if storageClassNames.include?(VALID_DESTINATION_DATASTORE_TYPES.first)
      result = true
    elsif storageClassNames.include?(VALID_DESTINATION_DATASTORE_TYPES.second)
      result = true
    else
      tistore_types = VALID_DESTINATION_DATASTORE_TYPES.join(', ')
      errors.add(:store_type, "The type of destination type must be in: #{store_types}")
    end
  end # of destination_datastore

  # Verify that Network type is LAN and belongs the source cluster .
  # irb(main):043:0> tm.transformation_mapping_items.first.source.lans.count
  # => 16
  #
  def source_network
    source_lan = source

    tmi_cluster = TransformationMappingItem.where(:source_type => "EmsCluster").first #TODO: handle collection?
    source_cluster = tmi_cluster.source
    tempCluster = source_lan.switch.host.ems_cluster

    if tempCluster == source_cluster
      result = true
    else
      network_types = VALID_SOURCE_NETWORK_TYPES.join(', ')
      errors.add(:network_types, "The network type must be in: #{network_types}")
    end
  end # of source_network

  # Verify that Network type is LAN or CloudNetwork and belongs the destination cluster.
  #
  def destination_network
    destination_lan = destination

    tmi_cluster = TransformationMappingItem.where(:source_type => "EmsCluster").first  #TODO: handle collection?
    destination_cluster = tmi_cluster.destination
    tempCluster = destination_lan.switch.host.ems_cluster

    if tempCluster == destination_cluster
      result = true
    else
      network_types = VALID_SOURCE_NETWORK_TYPES.join(', ')
      errors.add(:network_types, "The network type must be in: #{network_types}")
    end
  end # of destination_network

end # of cla