class CloudTenant < ApplicationRecord
  include NewWithTypeStiMixin
  include VirtualTotalMixin

  belongs_to :ext_management_system, :foreign_key => "ems_id", :class_name => "ManageIQ::Providers::CloudManager"
  has_many   :security_groups
  has_many   :cloud_networks
  has_many   :cloud_subnets
  has_many   :network_ports
  has_many   :network_routers
  has_many   :vms
  has_many   :vms_and_templates
  has_many   :miq_templates
  has_many   :floating_ips
  has_many   :cloud_volumes
  has_many   :cloud_volume_snapshots
  has_many   :cloud_object_store_containers
  has_many   :cloud_object_store_objects
  has_many   :cloud_resource_quotas

  alias_method :direct_cloud_networks, :cloud_networks

  acts_as_miq_taggable

  acts_as_tree

  virtual_total :total_vms, :vms

  def all_cloud_networks
    direct_cloud_networks + shared_cloud_networks
  end

  def shared_cloud_networks
    try(:ext_management_system).try(:cloud_networks).try(:where, :shared => true) || []
  end

  def self.post_refresh_ems(ems_id, _)
    ems = ExtManagementSystem.find(ems_id)

    MiqQueue.put_unless_exists(
      :class_name  => ems.class,
      :instance_id => ems_id,
      :method_name => 'sync_cloud_tenants_with_tenants',
      :zone        => ems.my_zone
    ) if ems.supports_cloud_tenants?
  end
end
