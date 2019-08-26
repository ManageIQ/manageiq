class TransformationMappingItem < ApplicationRecord
  belongs_to :transformation_mapping
  belongs_to :source,      :polymorphic => true
  belongs_to :destination, :polymorphic => true

  validates :source_id, :uniqueness => {:scope => [:transformation_mapping_id, :source_type, :destination_type]}

  validate :source_cluster,      :if => -> { source.kind_of?(EmsCluster) }
  validate :destination_cluster, :if => -> { destination.kind_of?(EmsCluster) || destination.kind_of?(CloudTenant) }

  after_create :validate_source_datastore,    :if => -> { source.kind_of?(Storage) }
  after_create :validate_destination_datastore, :if => -> { destination.kind_of?(Storage) || destination.kind_of?(CloudVolume) }

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

  def validate_source_datastore
    tm                   = transformation_mapping
    tmis                 = tm.transformation_mapping_items.where(:source_type => "EmsCluster")
    src_cluster_storages = tmis.collect(&:source).collect(&:storages).flatten
    source_storage       = source

    unless src_cluster_storages.include?(source_storage)
      errors.add(:source, "Source cluster storages must include source storage: #{source_storage}")
      cleanup(tm)
    end
  end

  def validate_destination_datastore
    tm                  = transformation_mapping
    destination_storage = destination

    if destination.kind_of?(Storage) # red hat
      tmis                 = tm.transformation_mapping_items.where(:destination_type=> "EmsCluster")
      dst_cluster_storages = tmis.collect(&:destination).collect(&:storages).flatten
    elsif destination.kind_of?(CloudVolume) # Openstack
      tmis                 = tm.transformation_mapping_items.where(:destination_type => "CloudTenant")
      dst_cluster_storages = tmis.collect(&:destination).collect(&:cloud_volumes).flatten
    end

    unless dst_cluster_storages.include?(destination_storage)
      errors.add(:destination, "Destination cluster storages must include destination storage: #{destination_storage}")
      cleanup(tm)
    end
  end

  # cleanup if transformation mapping or any of its items are invalid
  def cleanup (tm)
    tmis = TransformationMappingItem.where(:tranformation_mapping_id => tm.id)
    tm.delete
    tmis.collect { |item| item.delete }
  end
end
