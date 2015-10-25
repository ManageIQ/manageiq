class ContainerVolume < ApplicationRecord
  include ReportableMixin
  belongs_to :parent, :polymorphic => true
end
