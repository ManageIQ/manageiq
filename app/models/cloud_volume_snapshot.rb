class CloudVolumeSnapshot < ApplicationRecord
  include NewWithTypeStiMixin
  include ReportableMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager"
  belongs_to :cloud_tenant
  belongs_to :cloud_volume
  has_many   :based_volumes, :class_name => 'CloudVolume'

  virtual_column :total_based_volumes, :type => :integer, :uses => :based_volumes

  def total_based_volumes
    based_volumes.size
  end
end
