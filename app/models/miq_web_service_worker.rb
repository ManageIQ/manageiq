class MiqWebServiceWorker < MiqWorker
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
    %w[manageiq_default ui_dependencies]
  end

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_WEB_SERVICE_WORKERS
  end

  def self.preload_for_worker_role
    super
    Api::ApiConfig.collections.each { |_k, v| v.klass.try(:constantize).try(:descendants) }
  end

  def container_port
    3001
  end

  def configure_service_worker_deployment(definition)
    super

    definition[:spec][:template][:spec][:containers].first[:volumeMounts] << {:name => "api-httpd-config", :mountPath => "/etc/httpd/conf.d"}
    definition[:spec][:template][:spec][:volumes] << {:name => "api-httpd-config", :configMap => {:name => "api-httpd-configs", :defaultMode => 420}}

    if ENV["API_SSL_SECRET_NAME"].present?
      definition[:spec][:template][:spec][:containers].first[:volumeMounts] << {:name => "api-httpd-ssl", :mountPath => "/etc/pki/tls"}
      definition[:spec][:template][:spec][:volumes] << {:name => "api-httpd-ssl", :secret => {:secretName => ENV["API_SSL_SECRET_NAME"], :items => [{:key => "api_crt", :path => "certs/server.crt"}, {:key => "api_key", :path => "private/server.key"}], :defaultMode => 400}}
    end
  end
end
