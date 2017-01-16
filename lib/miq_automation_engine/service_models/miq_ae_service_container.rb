module MiqAeMethodService
  class MiqAeServiceContainer < MiqAeServiceModelBase
    expose :container_group,          :association => true
    expose :ext_management_system,    :association => true
    expose :container_node,           :association => true
    expose :container_replicator,     :association => true
    expose :container_project,        :association => true
    expose :old_container_project,    :association => true
    expose :container_definition,     :association => true
    expose :container_image,          :association => true
    expose :container_image_registry, :association => true
    expose :security_context,         :association => true
    expose :metrics
    expose :metric_rollups
    expose :vim_performance_states

    expose :is_tagged_with?
    expose :tags
  end
end
