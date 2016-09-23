class CloudVolumeBackup < ApplicationRecord
  include NewWithTypeStiMixin
  include VirtualTotalMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager"
  belongs_to :availability_zone
  belongs_to :cloud_volume
end
