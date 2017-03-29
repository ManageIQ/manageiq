module ManageIQ::Providers::Openstack::InfraManager::Host::Operations
  include ActiveSupport::Concern

  def ironic_fog_node
    connection_options = {:service => "Baremetal"}
    ext_management_system.with_provider_connection(connection_options) do |service|
      service.nodes.get(uid_ems)
    end
  end

  def set_node_maintenance_queue(userid)
    task_opts = {
      :action => "setting node maintenance on Host for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'set_node_maintenance',
      :instance_id => id,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => []
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def set_node_maintenance
    ironic_fog_node.set_node_maintenance(:reason=>"CFscaledown")
  end

  def unset_node_maintenance_queue(userid)
    task_opts = {
      :action => "unsetting node maintenance on Host for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'unset_node_maintenance',
      :instance_id => id,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => []
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def unset_node_maintenance
    ironic_fog_node.unset_node_maintenance
  end

  def external_get_node_maintenance
    ironic_fog_node.maintenance
  end

  def ironic_set_power_state_queue(userid = "system",
                                   power_state = "power off")
    task_opts = {
      :action  => "Set Ironic Node Power State",
      :user_id => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :method_name => "ironic_set_power_state",
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :args        => [power_state],
      :zone        => my_zone
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def ironic_set_power_state(power_state = "power off")
    connection = ext_management_system.openstack_handle.detect_baremetal_service
    response = connection.set_node_power_state(uid_ems, power_state)

    if response.status == 202
      EmsRefresh.queue_refresh(ext_management_system)
    end
  rescue => e
    _log.error "node=[#{name}], error: #{e}"
    raise MiqException::MiqOpenstackInfraHostSetPowerStateError, e.to_s, e.backtrace
  end
end
