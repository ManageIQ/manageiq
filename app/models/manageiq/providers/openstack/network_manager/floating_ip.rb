class ManageIQ::Providers::Openstack::NetworkManager::FloatingIp < ::FloatingIp
  include ProviderObjectMixin
  include AsyncDeleteMixin
  include SupportsFeatureMixin

  supports :create_floating_ip
  supports :delete_floating_ip
  supports :update_floating_ip

  def self.raw_create_floating_ip(ext_management_system, options)
    cloud_tenant = options.delete(:cloud_tenant)
    floating_ip = nil
    floating_network_id = CloudNetwork.find(options[:cloud_network_id]).ems_ref

    raw_options = remapping(options)

    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      floating_ip = service.create_floating_ip(floating_network_id, raw_options)
    end
    {:ems_ref => floating_ip['id'], :name => options[:name]}
  rescue => e
    _log.error "floating_ip=[#{options[:name]}], error: #{e}"
    raise MiqException::MiqFloatingIpCreateError, e.to_s, e.backtrace
  end

  def self.remapping(options)
    new_options = options.dup
    new_options[:floating_ip_address] = options[:address] if options[:address]
    new_options[:tenant_id] = CloudTenant.find(options[:cloud_tenant_id]).ems_ref if options[:cloud_tenant_id]
    new_options[:port_id] = options[:network_port_ems_ref] if options[:network_port_ems_ref]
    new_options.delete(:address)
    new_options.delete(:cloud_network_id)
    new_options.delete(:network_port_ems_ref)
    new_options.delete(:cloud_tenant_id)
    new_options
  end

  def raw_delete_floating_ip
    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      service.delete_floating_ip(ems_ref)
    end
  rescue => e
    _log.error "floating_ip=[#{name}], error: #{e}"
    raise MiqException::MiqFloatingIpDeleteError, e.to_s, e.backtrace
  end

  def delete_floating_ip_queue(userid)
    task_opts = {
      :action => "deleting Floating IP for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'raw_delete_floating_ip',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => []
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def raw_update_floating_ip(options)
    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      if options[:network_port_ems_ref].empty?
        service.disassociate_floating_ip(ems_ref)
      else
        service.associate_floating_ip(ems_ref, options[:network_port_ems_ref])
      end
    end
  rescue => e
    _log.error "floating_ip=[#{name}], error: #{e}"
    raise MiqException::MiqFloatingIpUpdateError, e.to_s, e.backtrace
  end

  def update_floating_ip_queue(userid, options = {})
    task_opts = {
      :action => "updating Floating IP for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'raw_update_floating_ip',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.connection_options(cloud_tenant = nil)
    connection_options = {:service => "Network"}
    connection_options[:tenant_name] = cloud_tenant.name if cloud_tenant
    connection_options
  end

  private

  def connection_options(cloud_tenant = nil)
    self.class.connection_options(cloud_tenant)
  end
end
