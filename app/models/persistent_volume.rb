class PersistentVolume < ContainerVolume
  acts_as_miq_taggable
  include NewWithTypeStiMixin
  serialize :capacity, :type => Hash
  delegate :name, :to => :parent, :prefix => true, :allow_nil => true
  has_many :container_volumes, -> { where(:type => 'ContainerVolume') }, :through => :persistent_volume_claim
  has_many :parents, -> { distinct }, :through => :container_volumes, :source_type => 'ContainerGroup'

  virtual_attribute :parent_name, :string
  virtual_attribute :storage_capacity, :string

  def container_groups
    parents
  end

  def container_groups=(objects)
    self.parents = objects
  end

  def storage_capacity
    capacity[:storage]
  end
end
