class MiqUiWorker < MiqWorker
  require_nested :Runner

  self.required_roles = ['user_interface']

  STARTING_PORT = 3000

  def friendly_name
    @friendly_name ||= "User Interface Worker"
  end

  include MiqWebServerWorkerMixin
  include MiqWorker::ServiceWorker

  def self.bundler_groups
    %w[manageiq_default ui_dependencies graphql_api]
  end

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_UI_WORKERS
  end

  def self.preload_for_worker_role
    super
    Api::ApiConfig.collections.each { |_k, v| v.klass.try(:constantize).try(:descendants) }
  end

  def container_port
    3001
  end

  def container_image_name
    "manageiq-ui-worker"
  end

  def container_image
    ENV["UI_WORKER_IMAGE"] || default_image
  end

  def configure_service_worker_deployment(definition)
    super

    definition[:spec][:template][:spec][:containers].first[:volumeMounts] << {:name => "ui-httpd-configs", :mountPath => "/etc/httpd/conf.d"}
    definition[:spec][:template][:spec][:volumes] << {:name=>"ui-httpd-configs", :configMap=>{:name=>"ui-httpd-configs", :defaultMode=>420}}
  end
end
