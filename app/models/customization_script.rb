class CustomizationScript < ApplicationRecord
  include NewWithTypeStiMixin
  include DeprecationMixin

  acts_as_miq_taggable
  deprecate_belongs_to(:provisioning_manager, :ext_management_system)
  belongs_to(:ext_management_system, :foreign_key => "manager_id")
end
