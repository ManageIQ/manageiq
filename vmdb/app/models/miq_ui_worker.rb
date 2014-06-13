class MiqUiWorker < MiqWorker
  REQUIRED_ROLE = 'user_interface'
  self.required_roles = [REQUIRED_ROLE]
  self.check_for_minimal_role = false
  self.workers = lambda do
    if MiqServer.minimal_env?
      # Force 1 UI worker in minimal mode, unless 'noui' is an option, which is
      # done when the UI worker is debugged externally, such as in Netbeans.
      MiqServer.minimal_env_options.include?("noui") ? 0 : 1
    else
      self.worker_settings[:count]
    end
  end

  BALANCE_MEMBER_CONFIG_FILE = '/etc/httpd/conf.d/cfme-balancer-ui.conf'
  REDIRECTS_CONFIG_FILE      = '/etc/httpd/conf.d/cfme-redirects-ui'
  STARTING_PORT              = 3000
  LB_METHOD                  = :busy
  REDIRECTS                  = '/'
  CLUSTER                    = 'evmcluster_ui'

  def friendly_name
    @friendly_name ||= "User Interface Worker"
  end

  def self.validate_config_settings(configuration = VMDB::Config.new("vmdb"))
    if configuration.config.fetch_path(:workers, :worker_base, :ui_worker).nil?
      $log.info("MIQ(#{self.name}) Migrating Settings")
      configuration.merge_from_template(:workers, :worker_base, :ui_worker)
      roles = configuration.config.fetch_path(:server, :role).split(',')
      unless roles.include?(REQUIRED_ROLE)
        $log.info("MIQ(#{self.name}) Adding Default Role #{REQUIRED_ROLE}")
        roles << REQUIRED_ROLE
        configuration.config.store_path(:server, :role, roles.join(','))
      end
    end
  end

  include WebServerWorkerMixin
end
