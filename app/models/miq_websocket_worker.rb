require 'miq_apache'

class MiqWebsocketWorker < MiqWorker
  require_nested :Runner

  self.required_roles = ['websocket']

  RACK_APPLICATION           = WebsocketServer
  BALANCE_MEMBER_CONFIG_FILE = "#{MiqApache.config_dir}/manageiq-balancer-websocket.conf".freeze
  REDIRECTS_CONFIG_FILE      = "#{MiqApache.config_dir}/manageiq-redirects-websocket".freeze
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
