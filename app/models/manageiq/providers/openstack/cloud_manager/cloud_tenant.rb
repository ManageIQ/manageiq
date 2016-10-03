class ManageIQ::Providers::Openstack::CloudManager::CloudTenant < ::CloudTenant
  has_and_belongs_to_many :miq_templates,
                          :foreign_key             => "cloud_tenant_id",
                          :join_table              => "cloud_tenants_vms",
                          :association_foreign_key => "vm_id",
                          :class_name              => "ManageIQ::Providers::Openstack::CloudManager::Template"

  has_many :private_networks,
           :class_name => "ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Private"

  def all_private_networks
    private_networks + (try(:ext_management_system).try(:private_networks).try(:where, :shared => true) || [])
  end
end
