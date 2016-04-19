module ManageIQ::Providers::Openstack::InfraManager::Host::Operations
  include ActiveSupport::Concern

  def ironic_fog_node
    connection_options = {:service => "Baremetal"}
    ext_management_system.with_provider_connection(connection_options) do |service|
      service.nodes.get(uid_ems)
    end
  end

  def set_node_maintenance
    ironic_fog_node.set_node_maintenance(:reason=>"CFscaledown")
  end

  def unset_node_maintenance
    ironic_fog_node.unset_node_maintenance
  end

  def external_get_node_maintenance
    ironic_fog_node.maintenance
  end

  def nova_system_service
    # we need to be sure that host has compute service
    system_services.find_by(:name => 'openstack-nova-compute')
  end

  def nova_fog_service
    # TODO: check if host is part of OpenStack Infra
    # host's cluster needs cloud assigned
    cloud = ems_cluster.cloud
    # hostname of host in hypervisor is used to properly select service from OpenStack
    host_name = hypervisor_hostname
    fog_services = cloud.openstack_handle.compute_service.services
    fog_services.find { |s| s.host =~ /#{host_name}/ && s.binary == 'nova-compute' }
  end

  def nova_fog_enable_service
    nova_fog_service.enable
  end

  def nova_fog_disable_service
    nova_fog_service.disable
  end

  def nova_service_refresh_scheduling_status
    new_status = nova_fog_service.status
    nova_system_service.scheduling_status = new_status if %w(enabled disabled).include? new_status
    nova_system_service.save
  end
end
