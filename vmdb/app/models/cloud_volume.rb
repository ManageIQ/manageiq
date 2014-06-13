class CloudVolume < ActiveRecord::Base
  include NewWithTypeStiMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id
  belongs_to :availability_zone
  belongs_to :vm
  has_many   :cloud_volume_snapshots

  def self.available
    where(:vm_id => nil)
  end
end