class MiqWebServiceWorker < MiqWorker
  require_nested :Runner

  REQUIRED_ROLE = 'web_services'
  self.required_roles = [REQUIRED_ROLE]

  BALANCE_MEMBER_CONFIG_FILE = '/etc/httpd/conf.d/manageiq-balancer-ws.conf'
  REDIRECTS_CONFIG_FILE      = '/etc/httpd/conf.d/manageiq-redirects-ws'
  STARTING_PORT              = 4000
  LB_METHOD                  = :busy
  REDIRECTS                  = ['/api']
  CLUSTER                    = 'evmcluster_ws'

  def friendly_name
    @friendly_name ||= "Web Services Worker"
  end

  def self.validate_config_settings(configuration = VMDB::Config.new("vmdb"))
    if configuration.config.fetch_path(:workers, :worker_base, :web_service_worker).nil?
      _log.info("Migrating Settings")
      configuration.merge_from_template_if_missing(:workers, :worker_base, :web_service_worker)
      roles = configuration.config.fetch_path(:server, :role).split(',')
      unless roles.include?(REQUIRED_ROLE)
        _log.info("Adding Default Role #{REQUIRED_ROLE}")
        roles << REQUIRED_ROLE
        configuration.config.store_path(:server, :role, roles.join(','))
      end
    end
  end

  include MiqWebServerWorkerMixin
end
