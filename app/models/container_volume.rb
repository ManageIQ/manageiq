class ContainerVolume < ApplicationRecord
  belongs_to :parent, :polymorphic => true
end
