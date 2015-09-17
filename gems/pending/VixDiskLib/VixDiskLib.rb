require 'drb/drb'
require 'sync'
require 'ffi-vix_disk_lib/const'
require 'ffi-vix_disk_lib/enum'
#
# The path to the VixDiskLib directory to be added to the process' LD_LIBRARY_PATH
#
VIXDISKLIB_PATH = "/usr/lib/vmware-vix-disklib/lib64"
#
# Alias the New FFI Binding Class Name to the old C Binding Class Name
#
VixDiskLib_raw = FFI::VixDiskLib::API

class VixDiskLibError < RuntimeError
end

SERVER_PATH = File.expand_path(__dir__)
MIQ_ROOT    = File.expand_path(File.join(SERVER_PATH, "../../.."))
LOG_DIR     = File.join(MIQ_ROOT, "log")
LOG_FILE    = File.join(LOG_DIR, "vim.log")

class VixDiskLib
  VIXDISKLIB_FLAG_OPEN_READ_ONLY = FFI::VixDiskLib::API::VIXDISKLIB_FLAG_OPEN_READ_ONLY
  @initialized = nil
  @drb_services = []
  @connection_lock = Sync.new
  @shutting_down = nil

  #
  # Just stash the init arguments into a hash for now.
  # We will call init on the server every time a connect request is made.
  #
  def self.init(_info_logger = nil, _warn_logger = nil, _error_logger = nil, _lib_dir = nil)
    @initialized = true
    nil
  end

  def self.connect(connect_parms)
    @connection_lock.synchronize(:EX) do
      raise VixDiskLibError, "VixDiskLib.connect() failed: VixDiskLib not initialized" if @initialized.nil?
      raise VixDiskLibError, "VixDiskLib.connect() aborting: VixDiskLib shutting down" if @shutting_down
      vix_disk_lib_service = start_service
      @drb_services << vix_disk_lib_service
      #
      # Let the DRb service start before attempting to use it.
      # I can find no examples suggesting that this is required, but on my test machine it is indeed.
      #
      retry_limit = 5
      begin
        sleep 1
        vix_disk_lib_service.init
      rescue DRb::DRbConnError => e
        if retry_limit > 0
          sleep 1
          retry_limit -= 1
          retry
        else
          raise VixDiskLibError, "VixDiskLib.connect() failed: #{e} on VixDiskLib.init()"
        end
      end
      vix_disk_lib_service.connect(connect_parms)
    end
  end

  def self.exit
    @connection_lock.synchronize(:EX) do
      @shutting_down = true
      DRb.stop_service
      i = 0
      @drb_services.each do |vdl_service|
        i += 1
        $vim_log.info "VixDiskLib.exit: shutting down service #{i} of #{@drb_services.size}" if $vim_log
        unless vdl_service.nil?
          begin
            vdl_service.shutdown = true
          rescue DRb::DRbConnError
            $vim_log.info "VixDiskLib.exit: DRb connection closed due to service shutdown.  Continuing" if $vim_log
          end
        end
      end
      # Now clear data so we can start over if needed
      @initialized = nil
      num_services = @drb_services.size
      @drb_services.pop(num_services)
    end
  end

  #
  # Remove the Rails Environment Variables set in the Current Environment so that the SSL Libraries don't get loaded.
  #
  def self.setup_env
    vars_to_clear = %w(BUNDLE_BIN BUNDLE_BIN_PATH BUNDLE_GEMFILE
                       BUNDLE_ORIG_MANPATH EVMSERVER MIQ_GUID
                       RAILS_ENV RUBYOPT ORIGINAL_GEM_PATH)
    my_env = ENV.to_hash
    vars_to_clear.each do |key|
      my_env.delete(key)
    end

    my_env["LD_LIBRARY_PATH"] = (my_env["LD_LIBRARY_PATH"].to_s.split(':') << VIXDISKLIB_PATH).compact.join(":")
    my_env
  end

  def self.start_service
    #
    # TODO: Get the path to the server programatically - this server should probably live elsewhere.
    #
    my_env                   = setup_env
    uri_reader, uri_writer   = IO.pipe
    proc_reader, @proc_writer = IO.pipe

    server_cmd = "ruby #{SERVER_PATH}/VixDiskLibServer.rb"
    $vim_log.info "VixDiskLib.start_service: running command = #{server_cmd}"
    pid = Kernel.spawn(my_env, server_cmd,
                       [:out, :err]     => [LOG_FILE, "a"],
                       :unsetenv_others => true,
                       3                => uri_writer,
                       4                => proc_reader,
                       uri_reader       => :close,
                       @proc_writer     => :close)
    uri_writer.close
    proc_reader.close
    Process.detach(pid)
    $vim_log.info "VixDiskLibServer Process #{pid} started" if $vim_log
    DRb.start_service
    retry_num = 5
    uri = get_uri(uri_reader)
    begin
      sleep 1
      vix_disk_lib_service = DRbObject.new(nil, uri)
    rescue DRb::DRbConnError => e
      raise VixDiskLibError, "ERROR: VixDiskLib.connect() got #{e} on DRbObject.new_with_uri()" if retry_num == 0
      retry_num -= 1 && retry
    end
    vix_disk_lib_service
  end

  def self.get_uri(reader)
    if reader.eof
      #
      # Error - unable to read the URI with port number written into the pipe by the child (Server).
      #
      raise VixDiskLibError, "ERROR: VixDiskLib.connect() Unable to determine port used by VixDiskLib Server."
    end
    reader.gets
  end
end
