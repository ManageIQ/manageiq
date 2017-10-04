class CustomizationScript < ApplicationRecord
  include NewWithTypeStiMixin

  acts_as_miq_taggable
  belongs_to :provisioning_manager
end
