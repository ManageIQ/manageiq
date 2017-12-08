class MiqWebsocketWorker < MiqWorker
  require_nested :Runner

  self.required_roles = ['websocket']

  RACK_APPLICATION = WebsocketServer
  STARTING_PORT    = 5000

  def friendly_name
    @friendly_name ||= "Websocket Worker"
  end

  include MiqWebServerWorkerMixin
  include MiqWorker::ServiceWorker

  def self.supports_container?
    true
  end
end
