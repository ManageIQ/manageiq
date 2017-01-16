module MiqAeMethodService
  class MiqAeServiceContainerNode < MiqAeServiceModelBase
    expose :ext_management_system,    :association => true
    expose :container_groups,         :association => true
    expose :container_conditions,     :association => true
    expose :containers,               :association => true
    expose :container_images,         :association => true
    expose :container_services,       :association => true
    expose :container_routes,         :association => true
    expose :container_replicators,    :association => true
    expose :labels,                   :association => true
    expose :computer_system,          :association => true
    expose :lives_on,                 :association => true
    expose :hardware,                 :association => true
    expose :metrics,                  :association => true
    expose :metric_rollups,           :association => true
    expose :is_tagged_with?
    expose :tags
  end
end
