module MiqAeMethodService
  class MiqAeServiceContainerGroup < MiqAeServiceModelBase
    expose :containers,             :association => true
    expose :container_definitions,  :association => true
    expose :container_images,       :association => true
    expose :ext_management_system,  :association => true
    expose :labels,                 :association => true
    expose :node_selector_parts,    :association => true
    expose :container_node,         :association => true
    expose :container_services,     :association => true
    expose :container_replicator,   :association => true
    expose :container_project,      :association => true
    expose :container_build_pod,    :association => true
    expose :container_volumes,      :association => true
    expose :metrics,                :association => true
    expose :metric_rollups,         :association => true
    expose :vim_performance_states, :association => true
    expose :is_tagged_with?
    expose :tags
  end
end
