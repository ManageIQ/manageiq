module MiqAeMethodService
  class MiqAeServiceVm < MiqAeServiceVmOrTemplate
    def add_to_service(service)
      raise ArgumentError, "service must be a MiqAeServiceService" unless service.kind_of?(MiqAeMethodService::MiqAeServiceService)
      ar_method { wrap_results(Service.find_by_id(service.id).add_resource!(@object)) }
    end

    def remove_from_service
      ar_method { wrap_results(@object.direct_service.try(:remove_resource, @object)) }
    end
  end
end
