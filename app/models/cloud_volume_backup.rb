class CloudVolumeBackup < ApplicationRecord
  include NewWithTypeStiMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ExtManagementSystem"
  belongs_to :availability_zone
  belongs_to :cloud_volume
  belongs_to :cloud_tenant
  belongs_to :tenant
end
