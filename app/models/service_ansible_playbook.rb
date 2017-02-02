class ServiceAnsiblePlaybook < Service
  include ServiceConfigurationMixin

  def preprocess(service_context)
    _log.info("Preprocess for Service context: #{service_context}")
  end

  def execute(service_context)
    _log.info("Execute for Service context: #{service_context}")
  end

  def wait_for_completion(service_context)
    _log.info("Wait_for_completion for Service context: #{service_context}")
  end

  def refresh_provider(service_context)
    _log.info("Refresh_provider for Service context: #{service_context}")
  end

  def check_refreshed(service_context)
    _log.info("Check_refreshed for Service context: #{service_context}")
  end

  def postprocess(service_context)
    _log.info("Postprocess for Service context: #{service_context}")
  end

end
