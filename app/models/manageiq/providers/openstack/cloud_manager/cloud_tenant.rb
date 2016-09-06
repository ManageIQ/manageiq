class ManageIQ::Providers::Openstack::CloudManager::CloudTenant < ::CloudTenant
  has_and_belongs_to_many :miq_templates,
                          :foreign_key             => "cloud_tenant_id",
                          :join_table              => "cloud_tenants_vms",
                          :association_foreign_key => "vm_id",
                          :class_name              => "ManageIQ::Providers::Openstack::CloudManager::Template"
  has_and_belongs_to_many :flavors,
                          :foreign_key             => "cloud_tenant_id",
                          :join_table              => "cloud_tenants_flavors",
                          :association_foreign_key => "flavor_id",
                          :class_name              => "ManageIQ::Providers::Openstack::CloudManager::Flavor"
end
