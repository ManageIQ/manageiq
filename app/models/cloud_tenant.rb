class CloudTenant < ApplicationRecord
  TENANT_MAPPING_ASSOCIATIONS = %i(vms_and_templates).freeze

  include NewWithTypeStiMixin
  include VirtualTotalMixin
  extend ActsAsTree::TreeWalker

  belongs_to :ext_management_system, :foreign_key => "ems_id", :class_name => "ManageIQ::Providers::CloudManager"
  has_one    :source_tenant, :as => :source, :class_name => 'Tenant'
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

  acts_as_tree :order => 'name'

  virtual_total :total_vms, :vms

  def all_cloud_networks
    direct_cloud_networks + shared_cloud_networks
  end

  def shared_cloud_networks
    try(:ext_management_system).try(:cloud_networks).try(:where, :shared => true) || []
  end

  def update_source_tenant_associations
    TENANT_MAPPING_ASSOCIATIONS.each do |tenant_association|
      custom_update_method = "#{__method__}_for_#{tenant_association}"

      if respond_to?(custom_update_method)
        public_send(custom_update_method)
      end
    end
  end

  def update_source_tenant_associations_for_vms_and_templates
    vms_and_templates.each do |object|
      object.miq_group_id = source_tenant.default_miq_group_id
      object.save!
    end
  end

  def self.with_ext_management_system(ems_id)
    where(:ext_management_system => ems_id)
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

  def self.create_cloud_tenant(cloud_manager, cloud_tenant_name, options = {})
    klass = orchestration_stack_class_factory(cloud_manager)

    ems_ref, parent_ref = klass.raw_create_cloud_tenant(cloud_manager, cloud_tenant_name, options)

    parent_id = CloudTenant.find_by(:ems_ref => parent_ref).try(:id)

    klass.create(:name => cloud_tenant_name, :description => options[:description], :ems_ref => ems_ref,
                 :ext_management_system => cloud_manager, :parent_id => parent_id)
  end

  def self.orchestration_stack_class_factory(cloud_manager)
    "#{cloud_manager.class.name}::#{name}".constantize
  end

  def self.raw_create_cloud_tenant(_cloud_manager, _cloud_tenant_name, _options)
    raise NotImplementedError, _("raw_create_cloud_tenant must be implemented in a subclass")
  end
end
