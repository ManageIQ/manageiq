class MiqWebsocketWorker < MiqWorker
  require_nested :Runner

  self.required_roles = ['websocket']

  RACK_APPLICATION           = WebsocketServer
  BALANCE_MEMBER_CONFIG_FILE = '/etc/httpd/conf.d/manageiq-balancer-websocket.conf'
  REDIRECTS_CONFIG_FILE      = '/etc/httpd/conf.d/manageiq-redirects-websocket'
  STARTING_PORT              = 5000
  PROTOCOL                   = 'ws'
  LB_METHOD                  = :busy
  REDIRECTS                  = '/ws'
  CLUSTER                    = 'evmcluster_websocket'

  def friendly_name
    @friendly_name ||= "Websocket Worker"
  end

  include MiqWebServerWorkerMixin
end
