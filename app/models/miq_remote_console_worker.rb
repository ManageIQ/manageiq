class MiqRemoteConsoleWorker < MiqWorker
  require_nested :Runner

  self.required_roles = ['remote_console']

  RACK_APPLICATION = RemoteConsole::RackServer
  STARTING_PORT    = 5000

  def friendly_name
    @friendly_name ||= "Remote Console Worker"
  end

  include MiqWebServerWorkerMixin
  include MiqWorker::ServiceWorker

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_REMOTE_CONSOLE_WORKERS
  end
end
