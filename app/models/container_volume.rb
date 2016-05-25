class ContainerVolume < ApplicationRecord
  belongs_to :parent, :polymorphic => true
  belongs_to :persistent_volume_claim, :dependent => :destroy
end
