class ServiceGeneric < Service
  # A chance for taking options from automate script to override options from a service dialog
  def preprocess(_action, _options = {})
  end

  # Interact with external provider to act on this service item
  def execute(_action)
    raise NotImplementedError, _("execute must be implemented in a subclass")
  end

  # Check the provider execution status. It should return [true/false, status_message]
  # Return [false, nil] if the execution is still in progress.
  # Return [true, nil] if the execution is completed without error.
  # Return [true, message] if the execution completed with an error.
  def check_completed(_action)
    raise NotImplementedError, _("check_completed must be implemented in a subclass")
  end

  # Start a refresh
  def refresh(_action)
    raise NotImplementedError, _("refresh must be implemented in a subclass")
  end

  # Check the refresh status. It should return [true/false, status_message]
  # Return [false, nil] if the refresh is still in progress.
  # Return [true, nil] if the refresh is completed without error.
  # Return [true, message] if the refresh completed with an error.
  def check_refreshed(_action)
    raise NotImplementedError, _("check_refreshed must be implemented in a subclass")
  end

  # Execute after refresh is done. Do cleaning up or update linkage here
  def postprocess(_action)
  end

  def on_error(_action)
  end
end
