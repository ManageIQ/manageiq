class MiqUiWorker < MiqWorker
  require_nested :Runner

  self.required_roles = ['user_interface']
  self.check_for_minimal_role = false
  self.workers = lambda do
    if MiqServer.minimal_env?
      # Force 1 UI worker in minimal mode, unless 'no_ui' is an option, which is
      # done when the UI worker is debugged externally, such as in Netbeans.
      MiqServer.minimal_env_options.include?("no_ui") ? 0 : 1
    else
      worker_settings[:count]
    end
  end

  STARTING_PORT = 3000

  def friendly_name
    @friendly_name ||= "User Interface Worker"
  end

  include MiqWebServerWorkerMixin
  include MiqWorker::ServiceWorker

  def self.supports_container?
    true
  end

  def container_port
    3001
  end

  def container_image_name
    "manageiq/manageiq-ui-worker"
  end
end
