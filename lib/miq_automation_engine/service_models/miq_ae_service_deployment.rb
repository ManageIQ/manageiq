module MiqAeMethodService
  class MiqAeServiceDeployment < MiqAeServiceModelBase
    expose :container_node_deployment, :association => true
  end
end
