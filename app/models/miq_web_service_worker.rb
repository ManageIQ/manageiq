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

  def self.bundler_groups
    %w[manageiq_default graphql_api]
  end

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_WEB_SERVICE_WORKERS
  end
end
