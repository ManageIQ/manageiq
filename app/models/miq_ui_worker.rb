class MiqUiWorker < MiqWorker
  require_nested :Runner

  self.required_roles = ['user_interface']

  STARTING_PORT = 3000

  def friendly_name
    @friendly_name ||= "User Interface Worker"
  end

  include MiqWebServerWorkerMixin
  include MiqWorker::ServiceWorker

  def self.supports_container?
    true
  end

  def self.bundler_groups
    %w[manageiq_default ui_dependencies graphql_api]
  end

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_UI_WORKERS
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
end
