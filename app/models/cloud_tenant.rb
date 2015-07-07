class CloudTenant < ActiveRecord::Base
  include ReportableMixin
  include NewWithTypeStiMixin

  #attr_accessible :description, :ems_ref, :enabled, :name

  belongs_to :ext_management_system, :foreign_key => "ems_id", :class_name => "ManageIQ::Providers::CloudManager"
  has_many   :security_groups
  has_many   :cloud_networks
  has_many   :shared_cloud_networks, -> { where :shared => true }, :through => :ext_management_system, :source => :cloud_networks
  has_many   :vms
  has_many   :vms_and_templates
  has_many   :miq_templates
  has_many   :floating_ips
  has_many   :cloud_resource_quotas
  has_many   :cloud_volumes
  has_many   :cloud_volume_snapshots
  has_many   :cloud_object_store_containers
  has_many   :cloud_object_store_objects
  has_many   :cloud_resource_quotas

  alias_method :direct_cloud_networks, :cloud_networks

  acts_as_miq_taggable

  virtual_column :total_vms, :type => :integer, :uses => :vms

  def all_cloud_networks
    direct_cloud_networks + shared_cloud_networks
  end

  def total_vms
    vms.size
  end
end
