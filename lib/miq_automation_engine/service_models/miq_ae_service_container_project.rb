module MiqAeMethodService
  class MiqAeServiceContainerProject < MiqAeServiceModelBase
    expose :container_groups,       :association => true
    expose :container_routes,       :association => true
    expose :container_replicators,  :association => true
    expose :container_services,     :association => true
    expose :container_definitions,  :association => true
    expose :container_nodes,        :association => true
    expose :container_quotas,       :association => true
    expose :container_quota_items,  :association => true
    expose :container_limits,       :association => true
    expose :container_limit_items,  :association => true
    expose :container_builds,       :association => true
    expose :metrics,                :association => true
    expose :metric_rollups,         :association => true
    expose :vim_performance_states, :association => true
  end
end
