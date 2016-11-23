module MiqAeMethodService
  class MiqAeServiceContainerReplicator < MiqAeServiceModelBase
    expose :ext_management_system,    :association => true
    expose :container_groups,         :association => true
    expose :container_project,        :association => true
    expose :labels,                   :association => true
    expose :selector_parts,           :association => true
    expose :container_nodes,          :association => true
    expose :metrics,                  :association => true
    expose :metric_zones,             :association => true
    expose :is_tagged_with?
    expose :tags
  end
end
