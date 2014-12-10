class CloudVolumeSnapshot < ActiveRecord::Base
  include NewWithTypeStiMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "Ems::CloudProvider"
  belongs_to :cloud_tenant
  belongs_to :cloud_volume
  has_many   :based_volumes, :class_name => 'CloudVolume'
end
