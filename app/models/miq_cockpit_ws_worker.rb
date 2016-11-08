require 'miq_apache'

class MiqCockpitWsWorker < MiqWorker
  require_nested :Runner
  require_nested :Authenticator

  APACHE_CONF_FILE = '/etc/httpd/conf.d/manageiq-redirects-cockpit'.freeze
  self.required_roles = ['cockpit_ws']
  self.maximum_workers_count = 1

  def friendly_name
    @friendly_name ||= "Cockpit Worker"
  end

  def self.can_start_cockpit_ws?
    @supports_cockpit_ws ||= MiqCockpit::WS.can_start_cockpit_ws?
  end

  def self.should_start_worker?
    return false unless has_required_role?
    can_start_cockpit_ws?
  end

  def self.sync_workers
    install_apache_proxy_config if MiqEnvironment::Command.supports_apache?
    @workers = should_start_worker? ? 1 : 0
    super
  end

  def self.install_apache_proxy_config
    config_status = has_required_role?

    # Only restart apache if status has changed
    if @config_status != config_status
      @config_status = config_status
      if config_status
        MiqCockpit::ApacheConfig.new(MiqCockpitWsWorker.worker_settings).save(APACHE_CONF_FILE)
      elsif File.exist?(APACHE_CONF_FILE)
        File.truncate(APACHE_CONF_FILE, 0)
      end
      MiqServer.my_server.queue_restart_apache
    end
  end

  def kill
    pid = Process.pid
    Sys::ProcTable.ps.each do |process_struct|
      next unless process_struct.ppid == pid
      begin
        _log.info("#{format_full_log_msg} -- killing child process: PID [#{process_struct.pid}]")
        Process.kill(9, child_pid)
      rescue Errno::ESRCH
        _log.info("#{format_full_log_msg} -- child process with PID [#{process_struct.pid}] has been killed")
      rescue => err
        _log.info("#{format_full_log_msg} -- child process with PID [#{process_struct.pid}] has been killed, but with the following error: #{err}")
      end
    end

    super
  end
end
