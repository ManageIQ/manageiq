class MiqCockpitWsWorker < MiqWorker
  require_nested :Runner
  require_nested :Authenticator

  self.required_roles = ['cockpit_ws']
  self.maximum_workers_count = 1

  def friendly_name
    @friendly_name ||= "Cockpit Worker"
  end

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_COCKPIT_WS_WORKERS
  end

  def self.can_start_cockpit_ws?
    @supports_cockpit_ws ||= MiqCockpit::WS.can_start_cockpit_ws?
  end

  def self.should_start_worker?
    return false unless has_required_role?
    can_start_cockpit_ws?
  end

  def self.sync_workers
    @workers = should_start_worker? ? 1 : 0
    super
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
