class ServiceEmbeddedAnsible < ServiceAutomation
  def job(action = "Provision")
    service_resources.find_by(:name => action, :resource_type => 'OrchestrationStack').try(:resource)
  end
end
