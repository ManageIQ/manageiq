class CloudVolumeSnapshot < ApplicationRecord
  include NewWithTypeStiMixin
  include VirtualTotalMixin
  include ProviderObjectMixin
  include SupportsFeatureMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ExtManagementSystem"
  belongs_to :cloud_tenant
  belongs_to :cloud_volume
  has_many   :based_volumes, :class_name => 'CloudVolume'

  virtual_total :total_based_volumes, :based_volumes

  def self.class_by_ems(ext_management_system)
    ext_management_system && ext_management_system.class::CloudVolumeSnapshot
  end

  def self.my_zone(ems)
    # TODO(pblaho): find unified way how to do that
    ems ? ems.my_zone : MiqServer.my_zone
  end

  def my_zone
    self.class.my_zone(ext_management_system)
  end
end
