class TransformationMappingItem < ApplicationRecord
  belongs_to :transformation_mapping
  belongs_to :source,      :polymorphic => true
  belongs_to :destination, :polymorphic => true

  validates :source_id, :uniqueness => {:scope => [:transformation_mapping_id, :source_type]}

  validate :source_cluster,      :if => -> { source.kind_of?(EmsCluster) }
  validate :destination_cluster, :if => -> { destination.kind_of?(EmsCluster) || destination.kind_of?(CloudTenant) }

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
