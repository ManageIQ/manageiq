require 'miq-process'
require 'pid_file'

class EvmServer
  ##
  # String used as a title for a linux process. Visible in ps, htop, ...
  SERVER_PROCESS_TITLE = 'MIQ Server'.freeze

  def initialize
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
    new.start
  end
end
