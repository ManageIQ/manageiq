class ServiceAnsiblePlaybook < ServiceGeneric
  def execute(action)
    _log.info("Execute for Service context: #{action}")
  end

  def check_completed(action)
    _log.info("Check_completed for Service context: #{action}")
  end

  def refresh(action)
    _log.info("Refresh for Service context: #{action}")
  end

  def check_refreshed(action)
    _log.info("Check_refreshed for Service context: #{action}")
  end
end
