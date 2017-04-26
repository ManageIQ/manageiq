require 'miq-process'
require 'pid_file'

class EvmServer
  SOFT_INTERRUPT_SIGNALS = ["SIGTERM", "SIGUSR1", "SIGUSR2"]

  OPTIONS_PARSER_SETTINGS = [
    [:mode, 'EVM Server Mode', String],
  ]

  ##
  # String used as a title for a linux process. Visible in ps, htop, ...
  SERVER_PROCESS_TITLE = 'MIQ Server'.freeze

  def initialize(cfg = {})
    @cfg = cfg

    $log ||= Rails.logger
  end

  def process_hard_signal(s)
    exit_code = 1
    message   = "Interrupt signal (#{s}) received."
    begin
      safe_log(message, exit_code)
      MiqServer.kill
    ensure
      do_exit(message, exit_code)
    end
  end

  def process_soft_signal(s)
    MiqServer.stop
  ensure
    do_exit("Interrupt signal (#{s}) received.", 0)
  end

  def do_exit(message = nil, exit_code = 0)
    safe_log("#{message} Server exiting.", exit_code)
    exit exit_code
  end

  def safe_log(message = nil, exit_code = 0)
    meth = (exit_code == 0) ? :info : :error

    prefix = "MIQ(EvmServer) "
    pid    = "PID [#{Process.pid}] " rescue ""
    logmsg = "#{prefix}#{pid}#{message}"

    begin
      $log.send(meth, logmsg)
    rescue
      puts "#{meth.to_s.upcase}: #{logmsg}" rescue nil
    end
  end

  def start
    if pid = MiqServer.running?
      $log.warn("EVM is already running (PID=#{pid})")
      exit
    end

    PidFile.create(MiqServer.pidfile)
    set_process_title
    MiqServer.start
  rescue Interrupt => e
    process_hard_signal(e.message)
  rescue SignalException => e
    raise unless SOFT_INTERRUPT_SIGNALS.include?(e.message)
    process_soft_signal(e.message)
  end

  ##
  # Sets the server process' name if it is possible.
  #
  def set_process_title
    Process.setproctitle(SERVER_PROCESS_TITLE) if Process.respond_to?(:setproctitle)
  end

  def self.start(*args)
    # Parse the args into the global config variable
    cfg = {}

    opts = OptionParser.new
    self::OPTIONS_PARSER_SETTINGS.each do |key, desc, type|
      opts.on("--#{key} VAL", desc, type) { |v| cfg[key] = v }
    end
    opts.parse(*args)

    # Start the Server object
    new(cfg).start
  end
end
