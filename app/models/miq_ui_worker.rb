class MiqUiWorker < MiqWorker
  require_nested :Runner

  REQUIRED_ROLE = 'user_interface'
  self.required_roles = [REQUIRED_ROLE]
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

  BALANCE_MEMBER_CONFIG_FILE = '/etc/httpd/conf.d/manageiq-balancer-ui.conf'
  REDIRECTS_CONFIG_FILE      = '/etc/httpd/conf.d/manageiq-redirects-ui'
  STARTING_PORT              = 3000
  LB_METHOD                  = :busy
  REDIRECTS                  = '/'
  CLUSTER                    = 'evmcluster_ui'

  def friendly_name
    @friendly_name ||= "User Interface Worker"
  end

  def self.validate_config_settings(configuration = VMDB::Config.new("vmdb"))
    if configuration.config.fetch_path(:workers, :worker_base, :ui_worker).nil?
      _log.info("Migrating Settings")
      configuration.merge_from_template_if_missing(:workers, :worker_base, :ui_worker)
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
