class TransformationMappingItem < ApplicationRecord
  belongs_to :transformation_mapping
  belongs_to :source,      :polymorphic => true
  belongs_to :destination, :polymorphic => true

  validates :source_id, :uniqueness_when_changed => {:scope => [:transformation_mapping_id, :source_type, :destination_type]}

  validate :validate_source_cluster,      :if => -> { source.kind_of?(EmsCluster) }
  validate :validate_destination_cluster, :if => -> { destination.kind_of?(EmsCluster) || destination.kind_of?(CloudTenant) }

  validate :validate_source_datastore,      :if => -> { source.kind_of?(Storage) }
  validate :validate_destination_datastore, :if => -> { destination.kind_of?(Storage) || destination.kind_of?(CloudVolume) }

  validate :validate_source_network,      :if => -> { source.kind_of?(Lan) }
  validate :validate_destination_network, :if => -> { destination.kind_of?(Lan) || destination.kind_of?(CloudNetwork) }

  VALID_SOURCE_CLUSTER_PROVIDERS = %w[vmwarews].freeze
  VALID_DESTINATION_CLUSTER_PROVIDERS = %w[rhevm openstack].freeze

  def validate_source_cluster
    unless VALID_SOURCE_CLUSTER_PROVIDERS.include?(source.ext_management_system.emstype)
      source_types = VALID_SOURCE_CLUSTER_PROVIDERS.join(', ')
      errors.add(:source, "EMS type of source cluster must be in: #{source_types}")
    end
  end

  def validate_destination_cluster
    unless VALID_DESTINATION_CLUSTER_PROVIDERS.include?(destination.ext_management_system.emstype)
      destination_types = VALID_DESTINATION_CLUSTER_PROVIDERS.join(', ')
      errors.add(:destination, "EMS type of destination cluster or cloud tenant must be in: #{destination_types}")
    end
  end

  def validate_source_datastore
    tm                   = transformation_mapping
    tmis                 = tm.transformation_mapping_items.where(:source_type => "EmsCluster")
    src_cluster_storages = tmis.collect(&:source).flat_map(&:storages)
    source_storage       = source

    unless src_cluster_storages.include?(source_storage)
      errors.add(:source, "Source cluster storages must include source storage: #{source_storage}")
    end
  end

  def validate_destination_datastore
    tm                  = transformation_mapping
    destination_storage = destination

    if destination.kind_of?(Storage) # red hat
      tmis                 = tm.transformation_mapping_items.where(:destination_type=> "EmsCluster")
      dst_cluster_storages = tmis.collect(&:destination).flat_map(&:storages)
    elsif destination.kind_of?(CloudVolume) # Openstack
      tmis                 = tm.transformation_mapping_items.where(:destination_type => "CloudTenant")
      dst_cluster_storages = tmis.collect(&:destination).flat_map(&:cloud_volumes)
    end

    unless dst_cluster_storages.include?(destination_storage)
      errors.add(:destination, "Destination cluster storages must include destination storage: #{destination_storage}")
    end
  end

  def validate_source_network
    tm               = transformation_mapping
    tmin             = tm.transformation_mapping_items.where(:source_type => "EmsCluster")
    src_cluster_lans = tmin.collect(&:source).flat_map(&:lans)
    source_lan       = source

    unless src_cluster_lans.include?(source_lan)
      errors.add(:source, "Source cluster lans must include source lan: #{source_lan}")
    end
  end

  def validate_destination_network
    tm              = transformation_mapping
    destination_lan = destination

    if destination.kind_of?(Lan) # red hat
      tmin             = tm.transformation_mapping_items.where(:destination_type=> "EmsCluster")
      dst_cluster_lans = tmin.collect(&:destination).flat_map(&:lans)
    elsif destination.kind_of?(CloudNetwork) # Openstack, lans are of 'CloudNetwork' type
      tmin             = tm.transformation_mapping_items.where(:destination_type => "CloudTenant")
      dst_cluster_lans = tmin.collect(&:destination).flat_map(&:cloud_networks)
      dst_cluster_lans |= tmin.map(&:destination).map(&:ext_management_system).flat_map(&:cloud_networks).select(&:shared).uniq
    end

    unless dst_cluster_lans.include?(destination_lan)
      errors.add(:destination, "Destination cluster lans must include destination lan: #{destination_lan.inspect}")
    end
  end
end
