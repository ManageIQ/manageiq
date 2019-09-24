require 'miq-process'
require 'pid_file'

class EvmServer
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

  def start
    if pid = MiqServer.running?
      $log.warn("EVM is already running (PID=#{pid})")
      exit
    end

    PidFile.create(MiqServer.pidfile)
    set_process_title
    MiqServer.start
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
