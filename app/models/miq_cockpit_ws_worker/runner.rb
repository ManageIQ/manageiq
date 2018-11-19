class MiqCockpitWsWorker::Runner < MiqWorker::Runner
  BINDING_ADDRESS = ENV['BINDING_ADDRESS'] || (Rails.env.production? ? "127.0.0.1" : "0.0.0.0")

  def find_pids(cmd)
    pids = Set.new
    Sys::ProcTable.ps.each do |process_struct|
      pids << process_struct.pid if cmd =~ (process_struct.try(:cmdline) || "")
    end
    pids
  end

  def do_before_work_loop
    stop_active_cockpit_ws_processes
    start_drb_service
    start_cockpit_ws
  end

  def do_work
    check_cockpit_ws
  end

  def before_exit(_message, _exit_code)
    stop_cockpit_ws
    stop_drb_service
  end

  def check_cockpit_ws
    if cockpit_ws_alive?
      begin
        errbuf = @stderr.readpartial(1.megabyte) if @stderr && @stderr.ready?
        outbuf = @stdout.readpartial(1.megabyte) if @stdout && @stdout.ready?
      rescue EOFError
        _log.info("#{log_prefix} got EOF process exiting")
      end
      outbuf.split("\n").each { |msg| $log.info("cockpit-ws: #{msg.rstrip}") } if outbuf
      errbuf.split("\n").each { |msg| $log.error("cockpit-ws: #{msg.rstrip}") } if errbuf
    else
      _log.info("#{log_prefix} Cockpit-ws Process gone. Restarting...")
      start_cockpit_ws
    end
  end

  def start_cockpit_ws
    raise _("Cannot call start_cockpit_ws if a process already exists") if cockpit_ws_alive?
    _log.info("#{log_prefix} Starting cockpit-ws Process")
    start_cockpit_ws_process
    _log.info("#{log_prefix} Started cockpit-ws Process")
  end

  def start_cockpit_ws_process
    @pid, @stdout, @stderr = cockpit_ws_run
  rescue => err
    @stdout.close if @stdout
    @stderr.close if @stderr
    _log.error("#{log_prefix} cockpit-ws Process aborted because [#{err.message}]")
    _log.log_backtrace(err)
  end

  def stop_cockpit_ws
    if cockpit_ws_alive?
      _log.info("#{log_prefix} Shutting down cockpit-ws process...pid=#{@pid}")
      stop_cockpit_ws_process
      _log.info("#{log_prefix} Shutting down cockpit-ws process...Complete")
    end
  end

  def stop_cockpit_ws_process
    return unless @pid
    Process.kill("TERM", @pid)
    wait_on_cockpit_ws
  end

  # Waits for a cockpit-ws process to stop.  The process is expected to be
  #   in the act of shutting down, and thus it will wait 5 minutes
  #   before issuing a kill.
  def wait_on_cockpit_ws(pid)
    pid ||= @pid
    # TODO: Use Process.waitpid or one of its async variants
    begin
      Timeout.timeout(5.minutes.to_i) do
        loop do
          break unless process_alive?(pid)
          sleep 1
          heartbeat
        end
      end
    rescue Timeout::Error
      _log.info("#{log_prefix} Killing cockpit-ws process with pid=#{pid}")
      Process.kill(9, pid)
    end

    begin
      _, status = Process.waitpid2(pid)
      _log.info("#{log_prefix} cockpit-ws Process with pid=#{pid} exited with a status=#{status}")
    rescue Errno::ECHILD
      _log.info("#{log_prefix} cockpit-ws Process with pid=#{pid} exited")
    end

    reset_process_info
  end

  def reset_process_info
    @pid = @stdout = @stderr = nil
  end

  def find_cockpit_ws_processes
    find_pids(/cockpit-ws --port/)
  end

  def stop_active_cockpit_ws_processes
    find_cockpit_ws_processes.each do |pid|
      _log.info("#{log_prefix} Killing active cockpit-ws process with pid=#{pid}")
      Process.kill("TERM", pid)
      wait_on_cockpit_ws(pid)
    end
  end

  def cockpit_ws_alive?
    if process_alive?(@pid)
      true
    else
      reset_process_info
      false
    end
  end

  def process_alive?(pid)
    return false if pid.nil?
    process_struct = Sys::ProcTable.ps(pid)
    return false if process_struct.nil?
    return true if process_struct.state != "Z"

    _log.info("#{log_prefix} waiting to die")
    zombie_pid, status = Process.waitpid2(pid)
    _log.info("#{log_prefix} cockpit-ws Process with pid=#{zombie_pid} exited with a status=#{status}")
    false
  end

  def cockpit_ws_run
    _log.info("#{log_prefix} cockpit-ws process starting")

    opts = @worker_settings
    cockpit_ws = MiqCockpit::WS.new(opts)
    cockpit_ws.save_config

    require "open3"
    env = {
      "XDG_CONFIG_DIRS" => cockpit_ws.config_dir,
      "DRB_URI"         => @drb_uri
    }
    stdin, stdout, stderr, wait_thr = Open3.popen3(env, *cockpit_ws.command(BINDING_ADDRESS))
    stdin.close

    _log.info("#{log_prefix} cockpit-ws process started - pid=#{pid}")
    return wait_thr.pid, stdout, stderr
  end

  def check_drb_service
    alive = @drb_server ? @drb_server.alive? : false
    unless alive
      start_drb_service
    end
  end

  def start_drb_service
    require 'drb'
    require 'drb/acl'

    stop_drb_service
    acl = ACL.new(%w(deny all allow 127.0.0.1/32))

    if @drb_uri
      @drb_server = DRb::DRbServer.new(@drb_uri, MiqCockpitWsWorker::Authenticator, acl)
    else
      require 'tmpdir'
      Dir::Tmpname.create("cockpit", nil) do |path|
        @drb_server = DRb::DRbServer.new("drbunix://#{path}", MiqCockpitWsWorker::Authenticator, acl)
        FileUtils.chmod(0o750, path)
      end
    end

    @drb_uri = @drb_server.uri
    _log.info("#{log_prefix} Started drb Process at #{@drb_uri}")
  end

  def stop_drb_service
    @drb_server.stop_service if @drb_server
    @drb_server = nil
    _log.info("#{log_prefix} stopped drb Process at #{@drb_uri}")
  end
end
