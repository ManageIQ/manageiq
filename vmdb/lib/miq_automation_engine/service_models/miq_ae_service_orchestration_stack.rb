module MiqAeMethodService
  class MiqAeServiceOrchestrationStack < MiqAeServiceModelBase
    expose :parameters,             :association => true
    expose :resources,              :association => true
    expose :outputs,                :association => true
    expose :vms,                    :association => true
    expose :security_groups,        :association => true
    expose :cloud_networks,         :association => true
    expose :orchestration_template, :association => true
    expose :ext_management_system,  :association => true

    def add_to_service(service)
      raise ArgumentError, "service must be a MiqAeServiceService" unless service.kind_of?(MiqAeMethodService::MiqAeServiceService)
      ar_method { wrap_results(Service.find_by_id(service.id).add_resource!(@object)) }
    end
  end
end
