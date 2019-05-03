class TransformationMappingItem < ApplicationRecord
  belongs_to :transformation_mapping
  belongs_to :source,      :polymorphic => true
  belongs_to :destination, :polymorphic => true

  validates :source_id, :uniqueness => {:scope => [:transformation_mapping_id, :source_type]}

  validates :destination_type,
            :inclusion => { :in => %w[EmsCluster CloudTenant Storage Lan CloudVolumeType CloudNetwork] }

  validate :destination_cluster, :if => -> { destination_type.casecmp?('EmsCluster') }
  validate :source_cluster, :if => -> { source_type.casecmp?('EmsCluster') }

  VALID_SOURCE_CLUSTER_PROVIDERS    = %w[vmwarews]
  VALID_DESTINATION_CLUSTER_TYPES   = %w[EmsCluster CloudTenant]

  VALID_SOURCE_DATASTORE_TYPES      = %w[Storage]
  VALID_DESTINATION_DATASTORE_TYPES = %w[Storage CloudVolumeType]

  VALID_SOURCE_NETWORK_TYPES        = %w[LAN]
  VALID_DESTINATION_NETWORK_TYPES   = %w[LAN CloudNetwork]

  private

  # ----------------------------------------------------------------------------
  # First check if types are valid
  # ----------------------------------------------------------------------------

  # Validator used if the target is an EMS cluster. This is more specific than
  # the source_cluster validation because here it only validates against
  # EmsCluster types.
  #
  def destination_cluster
    unless VALID_DESTINATION_CLUSTER_TYPES.include?(destination.ext_management_system.emstype)
      destination_types = VALID_DESTINATION_CLUSTER_TYPES.join(', ')
      errors.add(:destination_type, "EMS type of target cluster must be in: #{destination_types}")
    end
  end

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
  end

  # Check the storage types are valid.
  #
  def destination_datastores
    # transformation_mapping_items.where(:destination_type => 'Storage').map(&:source)
    #
    # check the storages are valid types.
    # Question: have to deal with multiple storages.  I guess only one storage is passed in.  Multiple storages have
    # to be dealt by the validation call.
    #
    # Storage types can be NFS, VMFS, GlusterFS, do we need to verify those?  This doc doesnt talk about specific
    # filesystem
    #
    # from IRB: tm.transformation_mapping_items.first.source.storages.second.store_type
    # => "NFS"
    unless VALID_DESTINATION_DATASTORE_TYPES.include?(destination.where(:destination_type => 'Storage').map(&:store_type))
      store_types = VALID_DESTINATION_DATASTORE_TYPES.join(', ')
      errors.add(:store_type, "The type of destination type must be in: #{store_types}")
    end
  end

  # How to check the datastore(s) belong to the source.
  #
  def source_datastores
    # transformation_mapping_items.where(:source_type => 'Storage').map(&:source)
    unless VALID_SOURCE_DATASTORE_TYPES.include?(destination.where(:source_type => 'Storage').map(&:store_type))
      errors.add(:store_type, "The type of destination type must be in: #{store_types}")
    end
  end

  # Verify that Network type is LAN and belongs the source cluster .
  # irb(main):043:0> tm.transformation_mapping_items.first.source.lans.count
  # => 16
  #
  def source_networks
    transformation_mapping_items.where(:source_type => 'Lan').map(&:source)
  end

  # Verify that Network type is LAN or CloudNetwork and belongs the destination cluster.
  #
  def destination_networks
    transformation_mapping_items.where(:destination_type => 'Lan').map(&:source)
  end

  # ----------------------------------------------------------------------------
  # Verify that source and destination cluster type is not the same
  # ----------------------------------------------------------------------------

end
