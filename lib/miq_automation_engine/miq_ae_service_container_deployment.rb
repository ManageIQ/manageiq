module MiqAeMethodService
  class MiqAeServiceContainerDeployment < MiqAeServiceModelBase
    expose :container_node_deployment, :association => true
    expose :deployed_ext_management_system, :association => true
    expose :deployed_on_ext_management_system, :association => true

    def assign_container_deployment_node(options)
      object_send(:assign_container_deployment_node, options)
    end

    def add_deployment_provider(options)
      object_send(:add_deployment_provider, options)
    end
  end
end
