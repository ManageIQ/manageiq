require 'io/wait' # To support IO#ready? calls

class MiqReplicationWorker::Runner < MiqWorker::Runner
  def do_before_work_loop
    stop_active_replication_processes
    start_replicate
  end

  def do_work
    log_status
    check_replicate
  end

  def before_exit(_message, _exit_code)
    stop_rubyrep
  end

  def message_reset_replication(_args = nil)
    stop_rubyrep

    unless valid_destination_settings?
      _log.error("#{log_prefix} Replication configuration is invalid.")
      return
    end

    start_uninstall

    dest_conf = worker_settings.fetch_path(:replication, :destination)
    MiqRegionRemote.destroy_entire_region(MiqRegion.my_region_number, *dest_conf.values_at(:host, :port, :username, :password, :database, :adapter))

    wait_on_rubyrep # Wait on the uninstall in case it takes longer than the destroy
    start_replicate
  end

  def valid_destination_settings?
    dest_conf = worker_settings.fetch_path(:replication, :destination)
    dest_conf[:adapter] ||= "postgresql"
    region = MiqRegion.my_region
    host_user_pass = dest_conf.values_at(:host, :port, :username, :password, :database, :adapter)
    host_user_pass.none?(&:blank?) && MiqRegionRemote.region_valid?(region.guid, region.region, *host_user_pass)
  end

  def log_status_interval
    (worker_settings[:log_status_interval] || 1.minute).to_i_with_method
  end

  def log_status
    if @last_log_status.nil? || Time.now.utc > (@last_log_status + log_status_interval)
      @last_log_status = Time.now.utc
      count, added, deleted = @worker.class.check_status

      details = count > 0 ? RrPendingChange.backlog_details : {}

      _log.info("#{log_prefix} Replication Status: Current Backlog=[#{count}], Added=[#{added}], Deleted=[#{deleted}], Tables=[#{details.inspect}]")
    end
  end

  #
  # Rubyrep interaction methods
  #

  def start_replicate
    unless self.valid_destination_settings?
      _log.error("#{log_prefix} Replication configuration is invalid.")
      return
    end

    start_rubyrep(:replicate)
  end

  def check_replicate
    if rubyrep_alive?
      @stdout.readpartial(1.megabyte).split("\n").each { |msg| $log.info  "rubyrep: #{msg.rstrip}" } if @stdout && @stdout.ready?
      @stderr.readpartial(1.megabyte).split("\n").each { |msg| $log.error "rubyrep: #{msg.rstrip}" } if @stderr && @stderr.ready?
    else
      _log.info("#{log_prefix} Replicate Process gone. Restarting...")
      start_replicate
    end
  end

  def start_uninstall
    start_rubyrep(:uninstall)
  end

  def start_rubyrep(verb)
    raise _("Cannot call start_rubyrep if a process already exists") if rubyrep_alive?
    _log.info("#{log_prefix} Starting #{verb.to_s.humanize} Process")
    start_rubyrep_process(verb)
    _log.info("#{log_prefix} Started  #{verb.to_s.humanize} Process")
  end

  def start_rubyrep_process(verb)
    @pid, @stdout, @stderr = rubyrep_run(verb)
  rescue => err
    _log.error("#{log_prefix} #{verb.to_s.humanize} Process aborted because [#{err.message}]")
    _log.log_backtrace(err)
  end

  def stop_rubyrep
    if rubyrep_alive?
      _log.info("#{log_prefix} Shutting down replication process...pid=#{@pid}")
      Process.kill("INT", @pid)
      wait_on_rubyrep
      _log.info("#{log_prefix} Shutting down replication process...Complete")
    end
  end

  def wait_on_rubyrep
    # TODO: Use Process.waitpid or one of its async variants
    begin
      Timeout.timeout(5.minutes.to_i) do
        loop do
          break unless rubyrep_alive?
          sleep 1
          heartbeat
        end
      end
    rescue Timeout::Error
      _log.info("#{log_prefix} Killing replication process with pid=#{@pid}")
      Process.kill(9, @pid)
    end

    $log.info("#{log_prefix} rubyrep Waiting for process with pid=#{@pid}")
    pid, status = Process.waitpid2(@pid)
    _log.info("#{log_prefix} rubyrep Process with pid=#{pid} exited with a status=#{status}")

    @pid = @stdout = @stderr = nil
  end

  def find_rubyrep_processes
    MiqProcess.find_pids(/evm:dbsync:/)
  end

  def stop_active_replication_processes
    find_rubyrep_processes.each do |pid|
      _log.info("#{log_prefix} Killing active replication process with pid=#{pid}")
      Process.kill(9, pid)
    end
  end

  def rubyrep_alive?
    begin
      pid_state = MiqProcess.state(@pid) unless @pid.nil?
    rescue SystemCallError => err
      $log.error("#{log_prefix} rubyrep Process with pid=#{@pid} SystemCallError '#{err.message}' while checking process state")
      return false
    end

    return true unless pid_state.nil? || pid_state == :zombie || !child_process_recently_active?
    $log.info(
      "#{log_prefix} rubyrep Process with pid=#{@pid} child has not heartbeat since #{child_process_last_heartbeat}"
    ) unless child_process_recently_active?

    if pid_state == :zombie
      pid, status = Process.waitpid2(@pid)
      _log.info("#{log_prefix} rubyrep Process with pid=#{pid} exited with a status=#{status}")
    end

    $log.info("#{log_prefix} rubyrep Process with pid=#{@pid} is not alive pid_state=#{pid_state}")
    false
  end

  def child_process_heartbeat_file_init
    FileUtils.touch(child_process_heartbeat_settings[:file]) if child_process_heartbeat_settings[:file]
  end

  def child_process_recently_active?
    child_process_last_heartbeat && (child_process_last_heartbeat >= child_process_heartbeat_settings[:threshold].seconds.ago.utc)
  end

  def child_process_last_heartbeat
    hb_file = child_process_heartbeat_settings[:file]
    File.exist?(hb_file) ? File.mtime(hb_file).utc : nil
  end

  def child_process_heartbeat_settings
    {
      :file      => MiqRubyrep.heartbeat_file,
      :threshold => (worker_settings.fetch_path(:replication, :options, :heartbeat_threshold) || 300).to_i_with_method
    }
  end

  def rubyrep_run(verb)
    verb = :local_uninstall if verb == :uninstall

    $log.info("#{log_prefix} rubyrep process for verb=#{verb} starting")

    child_process_heartbeat_file_init

    require 'open4'
    pid, stdin, stdout, stderr = Open4.popen4(*(MiqEnvironment::Command.rake_command).split, "evm:dbsync:#{verb}")
    stdin.close

    _log.info("#{log_prefix} rubyrep process for verb=#{verb} started - pid=#{pid}")
    return pid, stdout, stderr
  end
end
