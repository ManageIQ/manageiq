module MiqAeMethodService
  class MiqAeServiceGenericObject < MiqAeServiceModelBase
    require 'drb'

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

    def ae_user_identity
      @ae_user = DRb.front.workspace.ae_user
      ar_method { @object.ae_user_identity(@ae_user, @ae_user.current_group, @ae_user.current_tenant) }
    end

    def method_missing(method_name, *args)
      ae_user_identity unless @ae_user
      args = convert_params_to_ar_model(args)
      results = object_send(method_name, *args)
      wrap_results(results)
    end

    def convert_params_to_ar_model(args)
      if args.kind_of?(Array)
        args.collect { |arg| convert_params_to_ar_model(arg) }
      elsif args.kind_of?(Hash)
        args.each { |k, v| args[k] = convert_params_to_ar_model(v) }
      else
        args.kind_of?(MiqAeMethodService::MiqAeServiceModelBase) ? args.object_send(:itself) : args
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      object_send(:respond_to?, method_name, include_private)
    end
  end
end
