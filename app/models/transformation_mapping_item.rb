class TransformationMappingItem < ApplicationRecord
  belongs_to :transformation_mapping
  belongs_to :source,      :polymorphic => true
  belongs_to :destination, :polymorphic => true

  validates :source_id, :uniqueness => {:scope => [:transformation_mapping_id, :source_type]}

  validate :source_cluster,      :if => -> { source.kind_of?(EmsCluster) }
  validate :destination_cluster, :if => -> { destination.kind_of?(EmsCluster) || destination.kind_of?(CloudTenant) }

  validate :source_datastore,      :if => -> { source.kind_of?(Storage) }
  validate :destination_datastore, :if => -> { destination.kind_of?(Storage) || destination.kind_of?(CloudVolume) }

  def destination_datastore
    if destination.kind_of?(Storage) # Redhat
      mapping_items = transformation_mapping.transformation_mapping_items.where(:destination_type=> "EmsCluster")
      dst_cluster_storages = mapping_items.collect(&:destination).collect(&:storages).flatten
    elsif destination.kind_of?(CloudVolume) # Openstack
      mapping_items = transformation_mapping.transformation_mapping_items.where(:destination_type => "CloudTenant")
      dst_cluster_storages = mapping_items.collect(&:destination).collect(&:cloud_volumes).flatten
    end

    unless dst_cluster_storages.include?(destination)
      errors.add(:destination, "cluster storages must include destination storage: #{destination}")
    end
  end

  def source_datastore
    mappings = transformation_mapping.transformation_mapping_items.where(:source_type => "EmsCluster")
    storages = mappings.collect(&:source).collect(&:storages).flatten

    unless storages.include?(source)
      errors.add(:source, "cluster storages must include source storage: #{source}")
    end
  end

  VALID_SOURCE_CLUSTER_PROVIDERS = %w[vmwarews].freeze
  VALID_DESTINATION_CLUSTER_PROVIDERS = %w[rhevm openstack].freeze

  def source_cluster
    unless VALID_SOURCE_CLUSTER_PROVIDERS.include?(source.ext_management_system.emstype)
      source_types = VALID_SOURCE_CLUSTER_PROVIDERS.join(', ')
      errors.add(:source, "EMS type of source cluster must be in: #{source_types}")
    end
  end

  def destination_cluster
    unless VALID_DESTINATION_CLUSTER_PROVIDERS.include?(destination.ext_management_system.emstype)
      destination_types = VALID_DESTINATION_CLUSTER_PROVIDERS.join(', ')
      errors.add(:destination, "EMS type of destination cluster or cloud tenant must be in: #{destination_types}")
    end
  end
end
