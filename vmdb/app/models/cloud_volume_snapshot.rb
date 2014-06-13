class CloudVolumeSnapshot < ActiveRecord::Base
  include NewWithTypeStiMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id
  belongs_to :cloud_volume
end