class MiqWebServiceWorker < MiqWorker
  require_nested :Runner

  self.required_roles = ['web_services']

  STARTING_PORT = 4000

  def friendly_name
    @friendly_name ||= "Web Services Worker"
  end

  include MiqWebServerWorkerMixin
  include MiqWorker::ServiceWorker

  def self.supports_container?
    true
  end
end
