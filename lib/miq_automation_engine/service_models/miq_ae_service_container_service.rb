module MiqAeMethodService
  class MiqAeServiceContainerService < MiqAeServiceModelBase
    expose :ext_management_system,          :association => true
    expose :container_groups,               :association => true
    expose :container_routes,               :association => true
    expose :container_service_port_configs, :association => true
    expose :container_project,              :association => true
    expose :labels,                         :association => true
    expose :selector_parts,                 :association => true
    expose :container_nodes,                :association => true
    expose :container_image_registry,       :association => true
    expose :metrics,                        :association => true
    expose :metric_rollups,                 :association => true
    expose :is_tagged_with?
    expose :tags
  end
end
