class PersistentVolume < ContainerVolume
  acts_as_miq_taggable
  delegate :name, :to => :parent, :prefix => true
end
