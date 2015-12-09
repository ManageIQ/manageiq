module MiqAeMethodService
  module MiqAeServiceVmdb
    def vmdb(model_name, *args)
      service = service_model(model_name)
      args.empty? ? service : service.find(*args)
    end

    def service_model(model_name)
      "MiqAeMethodService::MiqAeService#{model_name}".constantize
    rescue NameError
      service_model_lookup(model_name)
    end
  end
end
