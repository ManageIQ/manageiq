require 'workers/worker_base'
require 'io/wait' # To support IO#ready? calls

class ReplicationWorker < WorkerBase
  def do_before_work_loop
    stop_active_replication_processes
    start_replicate
  end

  def do_work
    log_status
    check_replicate
  end

  def before_exit(message, exit_code)
    stop_rubyrep
  end

  def message_reset_replication(args=nil)
    stop_rubyrep

    unless valid_destination_settings?
      $log.error("#{self.log_prefix} Replication configuration is invalid.")
      return
    end

    start_uninstall

    dest_conf = self.worker_settings.fetch_path(:replication, :destination)
    MiqRegionRemote.destroy_entire_region(MiqRegion.my_region_number, *dest_conf.values_at(:host, :port, :username, :password, :database, :adapter))

    wait_on_rubyrep # Wait on the uninstall in case it takes longer than the destroy
    start_replicate
  end

  def valid_destination_settings?
    dest_conf = self.worker_settings.fetch_path(:replication, :destination)
    dest_conf[:adapter] ||= "postgresql"
    region = MiqRegion.my_region
    host_user_pass = dest_conf.values_at(:host, :port, :username, :password, :database, :adapter)
    return host_user_pass.none?(&:blank?) && MiqRegionRemote.region_valid?(region.guid, region.region, *host_user_pass)
  end

  def log_status_interval
    (self.worker_settings[:log_status_interval] || 1.minute).to_i_with_method
  end

  def log_status
    if @last_log_status.nil? || Time.now.utc > (@last_log_status + log_status_interval)
      @last_log_status = Time.now.utc
      count, added, deleted = @worker.class.check_status
      $log.info("#{self.log_prefix} Replication Status: Current Backlog=[#{count}], Added=[#{added}], Deleted=[#{deleted}]")
    end
  end

  #
  # Rubyrep interaction methods
  #

  def start_replicate
    unless self.valid_destination_settings?
      $log.error("#{self.log_prefix} Replication configuration is invalid.")
      return
    end

    start_rubyrep(:replicate)
  end

  def check_replicate
    if rubyrep_alive?
      @stdout.readpartial(1.megabyte).split("\n").each { |msg| $log.info  "rubyrep: #{msg.rstrip}" } if @stdout && @stdout.ready?
      @stderr.readpartial(1.megabyte).split("\n").each { |msg| $log.error "rubyrep: #{msg.rstrip}" } if @stderr && @stderr.ready?
    else
      $log.info("#{self.log_prefix} Replicate Process gone. Restarting...")
      start_replicate
    end
  end

  def start_uninstall
    start_rubyrep(:uninstall)
  end

  def start_rubyrep(verb)
    raise "Cannot call start_rubyrep if a process already exists" if rubyrep_alive?
    $log.info("#{self.log_prefix} Starting #{verb.to_s.humanize} Process")
    start_rubyrep_process(verb)
    $log.info("#{self.log_prefix} Started  #{verb.to_s.humanize} Process")
  end

  def start_rubyrep_process(verb)
    begin
      @pid, @stdout, @stderr = rubyrep_run(verb)
    rescue => err
      $log.error("#{self.log_prefix} #{verb.to_s.humanize} Process aborted because [#{err.message}]")
      $log.log_backtrace(err)
    end
  end

  def stop_rubyrep
    if rubyrep_alive?
      $log.info("#{self.log_prefix} Shutting down replication process...pid=#{@pid}")
      Process.kill("INT", @pid)
      wait_on_rubyrep
      $log.info("#{self.log_prefix} Shutting down replication process...Complete")
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
    rescue TimeoutError
      $log.info("#{self.log_prefix} Killing replication process with pid=#{@pid}")
      Process.kill(9, @pid)
    end

    pid, status = Process.waitpid2(@pid)
    $log.info("#{self.log_prefix} rubyrep Process with pid=#{pid} exited with a status=#{status}")

    @pid = @stdout = @stderr = nil
  end

  def find_rubyrep_processes
    MiqProcess.find_pids(/evm:dbsync:/)
  end

  def stop_active_replication_processes
    find_rubyrep_processes.each do |pid|
      $log.info("#{self.log_prefix} Killing active replication process with pid=#{pid}")
      Process.kill(9, pid)
    end
  end

  def rubyrep_alive?
    begin
      pid_state = MiqProcess.state(@pid) unless @pid.nil?
    rescue SystemCallError
      return false
    end

    return true unless pid_state.nil? || pid_state == :zombie

    if pid_state == :zombie
      pid, status = Process.waitpid2(@pid)
      $log.info("#{self.log_prefix} rubyrep Process with pid=#{pid} exited with a status=#{status}")
    end

    return false
  end

  def rubyrep_run(verb)
    verb = :local_uninstall if verb == :uninstall

    $log.info("#{self.log_prefix} rubyrep process for verb=#{verb} starting")

    require 'open4'
    pid, stdin, stdout, stderr = Open4.popen4(*(MiqEnvironment::Command.rake_command).split, "evm:dbsync:#{verb}")
    stdin.close

    $log.info("#{self.log_prefix} rubyrep process for verb=#{verb} started - pid=#{pid}")
    return pid, stdout, stderr
  end
end
