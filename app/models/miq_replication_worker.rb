class MiqReplicationWorker < MiqWorker
  require_nested :Runner

  self.required_roles = ["database_synchronization"]
  self.include_stopping_workers_on_synchronize = true

  def self.replication_destination_connection_parameters
    config = worker_settings.fetch_path(:replication, :destination)
    MiqRegionRemote.connection_parameters_for(config)
  end

  def self.destination_host
    repl = find_current_in_my_region.first
    repl && repl.worker_settings.fetch_path(:replication, :destination, :host)
  end

  def self.replication_active?
    find_current_in_my_region.first
  end

  def friendly_name
    @friendly_name ||= _("Database Replication Worker")
  end

  #
  # Backlog Status
  #

  def self.check_status
    # last_id is done before count because count may take a while, and the
    #   numbers may get too far apart otherwise.
    last_id = RrPendingChange.last_id rescue 0
    count   = RrPendingChange.count rescue 0

    db      = MiqDatabase.first
    added   = db.last_replication_id.nil? ? count : [last_id - db.last_replication_id, 0].max
    deleted = db.last_replication_count.nil? ? 0 : added - (count - db.last_replication_count)
    db.update_attributes(:last_replication_count => count, :last_replication_id => last_id)
    return count, added, deleted
  end

  def self.current_backlog
    RrPendingChange.backlog rescue 0
  end

  #
  # Worker Management
  #

  def self.reset_replication
    repl = find_current.first
    repl.reset_replication unless repl.nil?
  end

  def reset_replication
    send_message_to_worker_monitor('reset_replication')
  end

  def kill
    MiqProcess.get_child_pids(pid).each do |child_pid|
      begin
        _log.info("#{format_full_log_msg} -- killing child process: PID [#{child_pid}]")
        Process.kill(9, child_pid)
      rescue Errno::ESRCH
        _log.info("#{format_full_log_msg} -- child process with PID [#{child_pid}] has been killed")
      rescue => err
        _log.info("#{format_full_log_msg} -- child process with PID [#{child_pid}] has been killed, but with the following error: #{err}")
      end
    end

    super
  end
end
