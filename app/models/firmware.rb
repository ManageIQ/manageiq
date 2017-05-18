class Firmware < ApplicationRecord
  include NewWithTypeStiMixin

  acts_as_miq_taggable

  belongs_to :hardware, :polymorphic => true
end
