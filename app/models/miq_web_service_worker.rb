class MiqWebServiceWorker < MiqWorker
  require_nested :Runner

  self.required_roles = ['web_services']

  BALANCE_MEMBER_CONFIG_FILE = '/etc/httpd/conf.d/cfme-balancer-ws.conf'
  REDIRECTS_CONFIG_FILE      = '/etc/httpd/conf.d/cfme-redirects-ws'
  STARTING_PORT              = 4000
  LB_METHOD                  = :busy
  REDIRECTS                  = ['/api']
  CLUSTER                    = 'evmcluster_ws'

  def friendly_name
    @friendly_name ||= "Web Services Worker"
  end

  include MiqWebServerWorkerMixin
end
