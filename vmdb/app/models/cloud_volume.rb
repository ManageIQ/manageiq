class CloudVolume < ActiveRecord::Base
  include NewWithTypeStiMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id
  belongs_to :availability_zone
  belongs_to :cloud_tenant
  belongs_to :base_snapshot, :class_name => 'CloudVolumeSnapshot'
  has_many   :cloud_volume_snapshots
  has_many   :attachments, :class_name => 'Disk', :as => :backing

  def self.available
    where(:vm_id => nil)
  end
end
