require 'miq-process'
require 'pid_file'

class EvmServer
  SOFT_INTERRUPT_SIGNALS = ["TERM", "USR1", "USR2"]
  HARD_INTERRUPT_SIGNALS = ["INT", "KILL"]

  OPTIONS_PARSER_SETTINGS = [
    [:mode, 'EVM Server Mode', String],
  ]

  def initialize(cfg = {})
    @cfg = cfg

    HARD_INTERRUPT_SIGNALS.each { |s| Signal.trap(s) { self.process_hard_signal(s) } if Signal.list.keys.include?(s) }
    SOFT_INTERRUPT_SIGNALS.each { |s| Signal.trap(s) { self.process_soft_signal(s) } if Signal.list.keys.include?(s) }

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
    begin
      # SOFT_INTERRUPT_SIGNALS get processed via MiqServer.stop in at_exit
    ensure
      do_exit("Interrupt signal (#{s}) received.", 0)
    end
  end

  def do_exit(message=nil, exit_code=0)
    safe_log("#{message} Server exiting.", exit_code)
    exit exit_code
  end

  def safe_log(message=nil, exit_code=0)
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

    at_exit {
      # register a shutdown method to run when server exits
      MiqServer.stop
    }

    PidFile.create(MiqServer.pidfile)
    MiqServer.start
  end

  def self.start(*args)
    # Parse the args into the global config variable
    cfg = {}

    opts = OptionParser.new
    self::OPTIONS_PARSER_SETTINGS.each do |key, desc, type|
      opts.on("--#{key} VAL", desc, type) {|v| cfg[key] = v}
    end
    opts.parse(*args)

    # Start the Server object
    self.new(cfg).start
  end
end

EvmServer.start(*ARGV) if MiqEnvironment::Process.is_rails_runner?
