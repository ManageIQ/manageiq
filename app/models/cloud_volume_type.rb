class CloudVolumeType < ApplicationRecord
  include NewWithTypeStiMixin
  include ProviderObjectMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ExtManagementSystem"

  def self.class_by_ems(ext_management_system)
    ext_management_system && ext_management_system.class::CloudVolumeType
  end
end
