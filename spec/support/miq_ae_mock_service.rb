class MiqAeMockService
  include MiqAeMethodService::MiqAeServiceObjectCommon
  include MiqAeMethodService::MiqAeServiceModelLegacy

  def initialize(hash = {})
    @root_hash = hash
  end

  def root
    @root_hash
  end

  def log(level, msg)
    $miq_ae_logger.send(level, "<AEMethod> #{msg}")
  end

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
