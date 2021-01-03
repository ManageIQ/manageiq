class MiqWebServiceWorker < MiqWorker
  require_nested :Runner

  self.required_roles = ['web_services']

  STARTING_PORT = 4000

  def friendly_name
    @friendly_name ||= "Web Services Worker"
  end

  include MiqWebServerWorkerMixin
  include MiqWorker::ServiceWorker

  def self.bundler_groups
    # TODO: The api process now looks at the existing UI session as of: https://github.com/ManageIQ/manageiq-api/pull/543
    # ui-classic should not be but is serialializing its classes into session, so we need to have access to them for deserialization
    # sandboxes;FC:-ActiveSupport::HashWithIndifferentAccess{I"dashboard;FC;q{I"perf_options;FS:0ApplicationController::Performance::Options$typ0:daily_date0:hourly_date0: days0:
    %w[manageiq_default ui_dependencies graphql_api]
  end

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_WEB_SERVICE_WORKERS
  end

  def self.preload_for_worker_role
    super
    Api::ApiConfig.collections.each { |_k, v| v.klass.try(:constantize).try(:descendants) }
  end
end
