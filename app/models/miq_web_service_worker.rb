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

  def self.preload_for_worker_role
    super
    Api::ApiConfig.collections.each { |_k, v| v.klass.try(:constantize).try(:descendants) }
  end
end
