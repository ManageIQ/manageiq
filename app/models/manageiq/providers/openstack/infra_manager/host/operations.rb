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
end
