class PersistentVolume < ContainerVolume
  acts_as_miq_taggable
  include NewWithTypeStiMixin
  serialize :capacity, Hash
  delegate :name, :to => :parent, :prefix => true
  has_many :container_volumes, -> { where(:type => 'ContainerVolume') }, :through => :persistent_volume_claim
  has_many :parents, -> { distinct }, :through => :container_volumes, :source_type => 'ContainerGroup'
  alias_attribute :container_groups, :parents

  virtual_column :storage_capacity, :type => :integer

  def storage_capacity
    capacity[:storage]
  end
end
