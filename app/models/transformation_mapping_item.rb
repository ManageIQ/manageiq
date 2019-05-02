class TransformationMappingItem < ApplicationRecord
  belongs_to :transformation_mapping
  belongs_to :source,      :polymorphic => true
  belongs_to :destination, :polymorphic => true

  validates :source_id, :uniqueness => {:scope => [:transformation_mapping_id, :source_type]}

  validates :destination_type, :inclusion => { :in => %w[EmsCluster CloudTenant Storage Lan CloudVolumeType CloudNetwork] }

  validate :target_cluster, :if => -> { destination_type.casecmp?('EmsCluster') }
  validate :source_cluster, :if => -> { source_type.casecmp?(EmsCluster) }

  private

  def target_cluster
    unless destination.ext_management_system.emstype.casecmp?('rhevm')
      errors.add(:destination_type, "EMS type of target cluster must be rhevm")
    end
  end

  def source_cluster
    unless source.ext_management_system.emstype.casecmp?('vmwarews')
      errors.add(:source_type, "EMS type of source cluster must be vmwarews")
    end
  end
end
