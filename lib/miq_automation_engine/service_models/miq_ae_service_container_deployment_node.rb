module MiqAeMethodService
  class MiqAeServiceContainerDeploymentNode < MiqAeServiceModelBase
    expose :vm_id
    expose :is_tagged_with?
    expose :tags
    expose :node_address
  end
end
