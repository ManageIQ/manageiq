require 'workers/worker_base'

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
    return host_user_pass.none? { |c| c.blank? } && MiqRegionRemote.region_valid?(region.guid, region.region, *host_user_pass)
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

  def mode
    @mode ||=
      if Platform::OS == :win32
        :thread
      else
        self.worker_settings[:mode] || :process
      end
  end

  def start_replicate
    unless self.valid_destination_settings?
      $log.error("#{self.log_prefix} Replication configuration is invalid.")
      return
    end

    start_rubyrep(:replicate)
  end

  def check_replicate
    self.send("check_replicate_#{mode}")
  end

  def start_uninstall
    start_rubyrep(:uninstall)
  end

  def start_rubyrep(verb)
    raise "Cannot call start_rubyrep if a #{mode} already exists" if rubyrep_alive?
    $log.info("#{self.log_prefix} Starting #{verb.to_s.humanize} #{mode.to_s.humanize}")
    self.send("start_rubyrep_#{mode}", verb)
    $log.info("#{self.log_prefix} Started  #{verb.to_s.humanize} #{mode.to_s.humanize}")
  end

  def stop_rubyrep
    self.send("stop_rubyrep_#{mode}")
  end

  def wait_on_rubyrep
    self.send("wait_on_rubyrep_#{mode}")
  end

  def rubyrep_alive?
    self.send("rubyrep_#{mode}_alive?")
  end

  def rubyrep_run(verb)
    self.send("rubyrep_run_in_#{mode}", verb)
  end

  #
  # Rubyrep process interaction methods
  #

  def check_replicate_process
    if rubyrep_alive?
      @stdout.readpartial(1.megabyte).split("\n").each { |msg| $log.info  "rubyrep: #{msg.rstrip}" } if @stdout && @stdout.ready?
      @stderr.readpartial(1.megabyte).split("\n").each { |msg| $log.error "rubyrep: #{msg.rstrip}" } if @stderr && @stderr.ready?
    else
      $log.info("#{self.log_prefix} Replicate Process gone. Restarting...")
      start_replicate
    end
  end

  def start_rubyrep_process(verb)
    begin
      @pid, @stdout, @stderr = rubyrep_run(verb)
    rescue => err
      $log.error("#{self.log_prefix} #{verb.to_s.humanize} Process aborted because [#{err.message}]")
      $log.log_backtrace(err)
    end
  end

  def stop_rubyrep_process
    if rubyrep_alive?
      $log.info("#{self.log_prefix} Shutting down replication process...pid=#{@pid}")
      Process.kill("INT", @pid)
      wait_on_rubyrep
      $log.info("#{self.log_prefix} Shutting down replication process...Complete")
    end
  end

  def wait_on_rubyrep_process
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
    pids = MiqProcess.find_pids(/evm:dbsync:/)
    if MiqEnvironment::Command.is_encrypted_appliance?
      pids = pids.collect { |pid| MiqProcess.get_child_pids(pid) }.flatten.compact
    end
    pids
  end

  def stop_active_replication_processes
    find_rubyrep_processes.each do |pid|
      $log.info("#{self.log_prefix} Killing active replication process with pid=#{pid}")
      Process.kill(9, pid)
    end
  end

  def rubyrep_process_alive?
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

  def rubyrep_run_in_process(verb)
    verb = :local_uninstall if verb == :uninstall

    require 'io/wait'
    require 'open4'
    pid, stdin, stdout, stderr = Open4.popen4(*(MiqEnvironment::Command.rake_command).split, "evm:dbsync:#{verb}")
    stdin.close

    $log.info("#{self.log_prefix} rubyrep process for verb=#{verb} starting")
    if MiqEnvironment::Command.is_encrypted_appliance?
      kids = MiqProcess.get_child_pids(pid)
      begin
        Timeout.timeout(60.seconds.to_i) do
          while kids.empty?
            sleep(1) # Sleep to allow OS to fire up the processes we spawned
            $log.info("#{self.log_prefix} #{kids.length} Checking for children of rubyrep pid=#{pid}")
            kids = MiqProcess.get_child_pids(pid)
          end
        end
      rescue TimeoutError
        do_exit("Cannot find child of rubyrep Process pid=#{pid}", 1)
      end

      if kids.length > 1
        $log.info("#{self.log_prefix} #{kids.length} children of rubyrep pid=#{pid}: #{kids.inspect}")

        kids.each do |pid|
          $log.info("#{self.log_prefix} Killing child process with pid=#{pid}")
          Process.kill(9, pid)
        end

        do_exit("rubyrep process has multiple children", 1)
      end

      # Overwrite pid with the child pid
      $log.info("#{self.log_prefix} rubyrep processes: parent pid=#{pid}, child pid=#{kids.first}")
      pid = kids.first.to_i
    end

    $log.info("#{self.log_prefix} rubyrep process for verb=#{verb} started - pid=#{pid}")
    return pid, stdout, stderr
  end

  #
  # Rubyrep thread interaction methods
  #

  def check_replicate_thread
    if !rubyrep_alive?
      $log.info("#{self.log_prefix} Replicate Thread gone. Restarting...")
      start_replicate
    end
  end

  def start_rubyrep_thread(verb)
    @tid = Thread.new do
      begin
        rubyrep_run(verb)
      rescue => err
        $log.error("#{self.log_prefix} #{verb.to_s.humanize} Thread aborted because [#{err.message}]")
        $log.log_backtrace(err)
      end
    end
  end

  def stop_rubyrep_thread
    if @tid
      $log.info("#{self.log_prefix} Shutting down replication thread gracefully...")
      $rubyrep_shutdown = true
      wait_on_rubyrep
      $log.info("#{self.log_prefix} Shutting down replication thread gracefully...Complete")
    end
  end

  def wait_on_rubyrep_thread
    @tid.join if @tid
    @tid = nil
  end

  def rubyrep_thread_alive?
    @tid && @tid.alive?
  end

  def rubyrep_run_in_thread(verb)
    Thread.current[:running_in_child_thread] = true
    require 'rubyrep'
    RR::CommandRunner.run(["--verbose", verb.to_s, "-c", File.join(Rails.root, "config", "replication.conf")])
  end
end
