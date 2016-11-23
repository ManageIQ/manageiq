module MiqAeMethodService
  class MiqAeServiceContainerQuota < MiqAeServiceModelBase
    expose :ext_management_system,    association => true
    expose :container_project,        association => true
    expose :container_quota_items,    association => true
  end
end
