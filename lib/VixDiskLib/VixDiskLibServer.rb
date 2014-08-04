$LOAD_PATH.push("#{File.dirname(__FILE__)}")
$LOAD_PATH.push("#{File.dirname(__FILE__)}/../VMwareWebService")
$LOAD_PATH.push("#{File.dirname(__FILE__)}/../util")

require 'drb/drb'
require 'log4r'
require 'time'
require 'vmdb-logger'
require 'vixdisklib_server'

class VixDiskLibError < RuntimeError
end

MIQ_ROOT    = "#{File.dirname(__FILE__)}/../../"
LOG_DIR     = MIQ_ROOT + "vmdb/log/"
LOG_FILE    = LOG_DIR + "vim.log"

$vim_log = VMDBLogger.new LOG_FILE

class VDDKFactory
  include DRb::DRbUndumped
  attr_accessor :shutdown
  attr_accessor :started
  attr_accessor :running

  def initialize
    @shutdown = nil
    @started = nil
    @running = nil
  end

  def writer_to_caller
    writer_fd = ENV['WRITER_FD']
    writer = IO.new(writer_fd.to_i)
    writer
  end

  def init
    VixDiskLibServer.init
    @started = true
  end

  def connect(connect_parms)
    load_error = FFI::VixDiskLib::API.load_error
    unless load_error.nil?
      @shutdown = true
      raise VixDiskLibError, load_error
    end
    @running = true
    VixDiskLibServer.connect(connect_parms)
  end

  def shut_down_drb
    thr = DRb.thread
    DRb.stop_service
    thr.join unless thr.nil?
    $vim_log.info "Finished shutting down DRb"
  end

  def shut_down_service(msg)
    $vim_log.info "#{msg}"
    VixDiskLibServer.__exit__ if @started
    @running = true
    $vim_log.info "VixDiskLibServer.__exit__ finished"
    shut_down_drb
  end

  #
  # Wait for the client to call our init function.
  # If it isn't called within "max_secs_to_wait" seconds, shut down the service.
  #
  def wait_for_status(status, secs_to_wait)
    start_time = Time.now
    sleep_secs = 2
    flag = (status == "started") ?  @started : @running
    until flag
      sleep sleep_secs
      #
      # Specifically check the shutdown flag in case we've been asked
      # to wait for a different flag.
      #
      break if @shutdown
      #
      # Check if we've waited the specified number of seconds.
      #
      current_time = Time.now
      if current_time - start_time > secs_to_wait
        elapsed = current_time - start_time
        msg = "ERROR: Maximum time for a call to VixDiskLib has been reached after #{elapsed} seconds."
        msg += "\nShutting down VixDiskLib Service"
        @shutdown = true
        shut_down_service(msg)
        raise VixDiskLibError, msg
      end
      flag = (status == "started") ?  @started : @running
    end
  end
end # class VDDKFactory

begin
  #
  # The object that handles requests on the server.
  #
  vddk = VDDKFactory.new
  VixDiskLibServer.server(vddk)
  STDOUT.sync = true
  STDERR.sync = true

  DRb.start_service(nil, vddk)
  DRb.primary_server.verbose = true
  uri_used = DRb.uri
  Thread.abort_on_exception = true
  $vim_log.info "Started DRb service on URI #{uri_used}"
  #
  # Now write the URI used back to the parent (client) process to let it know which port was selected.
  #
  writer = vddk.writer_to_caller
  writer.puts "URI:#{uri_used}"
  writer.flush
  #
  # Trap Handlers useful for testing and debugging.
  #
  trap('INT') { vddk.shut_down_service("Interrupt Signal received") && exit }
  trap('TERM') { vddk.shut_down_service("Termination Signal received") && exit }

  #
  # If we haven't been marked as started yet, wait for it.
  # We may return immediately because startup (and more) has already happened.
  #
  $vim_log.info "calling watchdog for startup"
  vddk.wait_for_status("started", 1800)
  $vim_log.info "startup has happened, shutdown flag is #{vddk.shutdown}"
  #
  # Wait for the DRb server thread to finish before exiting.
  #
  until vddk.shutdown
    #
    # Wait no longer than the specified number of seconds for any vddk call, otherwise shut down.
    #
    vddk.wait_for_status("running", 1800)
    Thread.pass unless vddk.shutdown
  end

  vddk.shut_down_service("Shutting Down VixDiskLibServer")
  $vim_log.info "Service has stopped"
rescue => err
  $vim_log.error "VixDiskLibServer ERROR: [#{err}]"
  $vim_log.debug "VixDiskLibServer ERROR: [#{err.backtrace.join("\n")}]"
end
