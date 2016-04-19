class PersistentVolume < ContainerVolume
  acts_as_miq_taggable
  include NewWithTypeStiMixin
  serialize :capacity, Hash
  delegate :name, :to => :parent, :prefix => true
end
