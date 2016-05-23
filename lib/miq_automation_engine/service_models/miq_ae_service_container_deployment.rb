module MiqAeMethodService
  class MiqAeServiceContainerDeployment < MiqAeServiceModelBase
    expose :container_deployment_nodes, :association => true
    expose :deployed_ems, :association => true
    expose :deployed_on_ems, :association => true
    expose :automation_task, :association => true
    expose :masters, :method => :masters
    expose :nodes, :method => :nodes
    expose :deployment_master, :method => :deployment_master

    def assign_container_deployment_node(vm_id, role)
      object_send(:container_nodes_by_role, role).each do |deployment_node|
        next unless deployment_node.vm_id.nil?
        deployment_node.vm_id = vm_id
      end
    end

    def add_deployment_provider(options)
      object_send(:add_deployment_provider, options)
    end

    def regenerate_ansible_inventory
      object_send(:generate_ansible_inventory)
    end

    def regenerate_ansible__subscription_inventory
      object_send(:generate_ansible_inventory_for_subscription)
    end

    def add_automation_task(task)
      ar_method do
        wrap_results(@object.automation_task = AutomationTask.find_by_id(task.id))
        @object.save!
      end
    end

    def customize(data)
      ar_method do
        wrap_results(@object.customizations = data)
        @object.save!
      end
    end
  end
end
