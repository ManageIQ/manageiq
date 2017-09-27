class CustomizationScript < ApplicationRecord
  include NewWithTypeStiMixin

  acts_as_miq_taggable
  belongs_to :ext_management_system, :foreign_key => "manager_id"
end
