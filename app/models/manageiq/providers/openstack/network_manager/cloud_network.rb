class ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork < ::CloudNetwork
  include SupportsFeatureMixin

  supports :create

  supports :delete do
    if ext_management_system.nil?
      unsupported_reason_add(:delete_cloud_network, _("The Cloud Network is not connected to an active %{table}") % {
        :table => ui_lookup(:table => "ext_management_systems")
      })
    end
  end

  supports :update do
    if ext_management_system.nil?
      unsupported_reason_add(:update_cloud_network, _("The Cloud Network is not connected to an active %{table}") % {
        :table => ui_lookup(:table => "ext_management_systems")
      })
    end
  end

  require_nested :Private
  require_nested :Public

  def self.remapping(options)
    new_options = options.dup
    new_options[:router_external] = options[:external_facing] if options[:external_facing]
    new_options.delete(:external_facing)
    new_options
  end

  def self.raw_create_cloud_network(ext_management_system, options)
    cloud_tenant = options.delete(:cloud_tenant)
    network = nil
    raw_options = remapping(options)
    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      network = service.networks.new(raw_options)
      network.save
    end
    {:ems_ref => network.id, :name => options[:name]}
  rescue => e
    _log.error "network=[#{options[:name]}], error: #{e}"
    raise MiqException::MiqNetworkCreateError, e.to_s, e.backtrace
  end

  def raw_delete_cloud_network
    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      service.delete_network(ems_ref)
    end
  rescue => e
    _log.error "network=[#{name}], error: #{e}"
    raise MiqException::MiqNetworkDeleteError, e.to_s, e.backtrace
  end

  def delete_cloud_network_queue(userid)
    task_opts = {
      :action => "deleting Cloud Network for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'raw_delete_cloud_network',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => []
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def raw_update_cloud_network(options)
    ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
      service.update_network(ems_ref, options)
    end
  rescue => e
    _log.error "network=[#{name}], error: #{e}"
    raise MiqException::MiqNetworkUpdateError, e.to_s, e.backtrace
  end

  def update_cloud_network_queue(userid, options = {})
    task_opts = {
      :action => "updating Cloud Network for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'raw_update_cloud_network',
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
