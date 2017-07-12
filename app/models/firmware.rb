class Firmware < ApplicationRecord
  include NewWithTypeStiMixin

  acts_as_miq_taggable

  belongs_to :hardware, :polymorphic => true
  belongs_to :guest_device
end
