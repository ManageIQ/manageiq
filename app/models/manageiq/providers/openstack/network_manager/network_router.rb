class ManageIQ::Providers::Openstack::NetworkManager::NetworkRouter < ::NetworkRouter
  include ProviderObjectMixin
  include AsyncDeleteMixin

  supports :create_network_router
  supports :delete_network_router
  supports :update_network_router
  supports :add_interface
  supports :remove_interface

  def self.create_network_router(ext_management_system, options)
    cloud_tenant = options.delete(:cloud_tenant)
    name = options.delete(:name)
    router = nil

    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      router = service.create_router(name, options).body
    end
    {:ems_ref => router['id'], :name => options[:name]}
  rescue => e
    _log.error "router=[#{options[:name]}], error: #{e}"
    raise MiqException::MiqNetworkRouterCreateError, e.to_s, e.backtrace
  end

  def delete_network_router
    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      service.delete_router(ems_ref)
    end
  rescue => e
    _log.error "router=[#{name}], error: #{e}"
    raise MiqException::MiqNetworkRouterDeleteError, e.to_s, e.backtrace
  end

  def delete_network_router_queue(userid)
    task_opts = {
      :action => "deleting Network Router for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'delete_network_router',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => []
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def update_network_router(options)
    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      service.update_router(ems_ref, options)
    end
  rescue => e
    _log.error "router=[#{name}], error: #{e}"
    raise MiqException::MiqNetworkRouterUpdateError, e.to_s, e.backtrace
  end

  def update_network_router_queue(userid, options = {})
    task_opts = {
      :action => "updating Network Router for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'update_network_router',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def add_interface(cloud_subnet_id)
    raise ArgumentError, _("Subnet ID cannot be nil") if cloud_subnet_id.nil?
    subnet = CloudSubnet.find(cloud_subnet_id)
    raise ArgumentError, _("Subnet cannot be found") if subnet.nil?

    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      service.add_router_interface(ems_ref, subnet.ems_ref)
    end
  rescue => e
    _log.error "router=[#{name}], error: #{e}"
    raise MiqException::MiqNetworkRouterAddInterfaceError, e.to_s, e.backtrace
  end

  def add_interface_queue(userid, cloud_subnet)
    task_opts = {
      :action => "Adding Interface to Network Router for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'add_interface',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [cloud_subnet.id]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def remove_interface(cloud_subnet_id)
    raise ArgumentError, _("Subnet ID cannot be nil") if cloud_subnet_id.nil?
    subnet = CloudSubnet.find(cloud_subnet_id)
    raise ArgumentError, _("Subnet cannot be found") if subnet.nil?

    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      service.remove_router_interface(ems_ref, subnet.ems_ref)
    end
  rescue => e
    _log.error "router=[#{name}], error: #{e}"
    raise MiqException::MiqNetworkRouterRemoveInterfaceError, e.to_s, e.backtrace
  end

  def remove_interface_queue(userid, cloud_subnet)
    task_opts = {
      :action => "Removing Interface from Network Router for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'remove_interface',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [cloud_subnet.id]
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
