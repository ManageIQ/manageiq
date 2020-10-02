class ContainerVolume < ApplicationRecord
  include CustomActionsMixin
  acts_as_miq_taggable
  belongs_to :parent, :polymorphic => true
  belongs_to :persistent_volume_claim, :dependent => :destroy

  def self.display_name(number = 1)
    n_('Container Volume', 'Container Volumes', number)
  end
end
