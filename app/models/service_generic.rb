class ServiceGeneric < Service
  # A chance for taking options from automate script to override options from a service dialog
  def preprocess(service_context)
  end

  # Interact with external provider to act on this service item
  # The result is called stack, normally a vmdb object. It can map to an object in the provider,
  # or even be a virtual object
  def execute(service_context)
    raise NotImplementedError, _("execute must be implemented in a subclass")
  end

  # Check the provider provision status. It should return [true/false, status_message]
  def wait_for_completion(service_context)
    raise NotImplementedError, _("wait_for_completion must be implemented in a subclass")
  end

  # Start a provider refresh
  def refresh_provider(service_context)
    raise NotImplementedError, _("refresh_provider must be implemented in a subclass")
  end

  # Check the refresh status. It should return [true/false, status_message]
  def check_refreshed(service_context)
    raise NotImplementedError, _("check_refreshed must be implemented in a subclass")
  end

  # Execute after refresh is done. Do cleaning up or update linkage here
  def postprocess((service_context), _options = {})
  end
end
