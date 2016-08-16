module MiqAeMethodService
  class MiqAeServiceGenericObject < MiqAeServiceModelBase
    def add_to_service(service)
      error_msg = "service must be a MiqAeServiceService"
      raise ArgumentError, error_msg unless service.kind_of?(MiqAeMethodService::MiqAeServiceService)
      ar_method { wrap_results(Service.find_by_id(service.id).add_resource!(@object)) }
    end

    def remove_from_service(service)
      error_msg = "service must be a MiqAeServiceService"
      raise ArgumentError, error_msg unless service.kind_of?(MiqAeMethodService::MiqAeServiceService)
      ar_method { wrap_results(Service.find_by_id(service.id).remove_resource(@object)) }
    end

    private

    def method_missing(method_name, *args)
      object_send(method_name, *args)
    end

    def respond_to_missing?(method_name, include_private = false)
      @object.respond_to?(method_name, include_private)
    end
  end
end
