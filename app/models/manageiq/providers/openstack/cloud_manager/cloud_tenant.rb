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

  def self.raw_create_cloud_tenant(ext_management_system, options)
    tenant = nil
    ext_management_system.with_provider_connection(connection_options) do |service|
      tenant = service.create_tenant(options)
    end
    {:ems_ref => tenant.id, :name => options[:name]}
  rescue => e
    _log.error "tenant=[#{options[:name]}], error: #{e}"
    raise MiqException::MiqCloudTenantCreateError, e.to_s, e.backtrace
  end

  def raw_update_cloud_tenant(options)
    ext_management_system.with_provider_connection(connection_options) do |service|
      service.update_tenant(ems_ref, options)
    end
  rescue => e
    _log.error "tenant=[#{name}], error: #{e}"
    raise MiqException::MiqCloudTenantUpdateError, e.to_s, e.backtrace
  end

  def raw_delete_cloud_tenant
    ext_management_system.with_provider_connection(connection_options) do |service|
      service.delete_tenant(ems_ref)
    end
  rescue => e
    _log.error "tenant=[#{name}], error: #{e}"
    raise MiqException::MiqCloudTenantDeleteError, e.to_s, e.backtrace
  end

  def self.connection_options
    connection_options = {:service => "Identity", :openstack_endpoint_type => 'adminURL'}
    connection_options
  end

  private

  def connection_options
    self.class.connection_options
  end
  private :connection_options
end
