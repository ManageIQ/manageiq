class CloudVolume < ActiveRecord::Base
  include NewWithTypeStiMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "Ems::CloudProvider"
  belongs_to :availability_zone
  belongs_to :cloud_tenant
  belongs_to :base_snapshot, :class_name => 'CloudVolumeSnapshot'
  has_many   :cloud_volume_snapshots
  has_many   :attachments, :class_name => 'Disk', :as => :backing

  def self.available
    joins("LEFT OUTER JOIN disks ON disks.backing_id = cloud_volumes.id")
      .where("disks.backing_id" => nil)
  end
end
