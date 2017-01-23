class ServiceGeneric < Service
  # A chance for taking options from automate script to override options from a service dialog
  def preprovision(_options = {})
  end

  # Interact with external provider to act on this service item
  # The result is called stack, normally a vmdb object. It can map to an object in the provider,
  # or even be a virtual object
  def provision
    raise NotImplementedError, _("provision must be implemented in a subclass")
  end

  # Check the provider provision status. It should return [true/false, status_message]
  def check_provisioned?
    raise NotImplementedError, _("check_provisioned must be implemented in a subclass")
  end

  # Start a provider refresh
  def refresh_provider
    raise NotImplementedError, _("refresh_provider must be implemented in a subclass")
  end

  # Check the refresh status. It should return [true/false, status_message]
  def check_refreshed
    raise NotImplementedError, _("check_refreshed must be implemented in a subclass")
  end

  # Execute after refresh is done. Do cleaning up or update linkage here
  def post_provision(_options = {})
  end
end
