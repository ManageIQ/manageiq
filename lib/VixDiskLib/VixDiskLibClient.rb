require 'drb/drb'
require 'VixDiskLib_FFI/const'
require 'VixDiskLib_FFI/enum'
#
# Alias the New FFI Binding Class Name to the old C Binding Class Name
#
VixDiskLib_raw = FFI::VixDiskLib::API

class VixDiskLibError < RuntimeError
end

MIQ_ROOT    = "/var/www/miq/"
SERVER_PATH = MIQ_ROOT + "lib/VixDiskLib/"
LOG_DIR     = MIQ_ROOT + "vmdb/log/"
LOG_FILE    = LOG_DIR + "vim.log"

class VixDiskLib
  @vix_disk_lib_service = nil
  VIXDISKLIB_FLAG_OPEN_READ_ONLY = FFI::VixDiskLib::API::VIXDISKLIB_FLAG_OPEN_READ_ONLY
  @init_parms = {}

  #
  # Just stash the init arguments into a hash for now.
  # We will call init on the server every time a connect request is made.
  #
  def self.init(info_logger = nil, warn_logger = nil, error_logger = nil, lib_dir = nil)
    @init_parms[:info] = info_logger
    @init_parms[:warn] = warn_logger
    @init_parms[:error] = error_logger
    @init_parms[:lib_dir] = lib_dir
    nil
  end

  def self.connect(connect_parms)
    #
    # TODO: Get the path to the server programatically - this server should probably live elsewhere.
    # TODO: Find a better place for this log file - the real log dir.
    #
    my_env = setup_env
    reader, writer = IO.pipe
    writerfd = writer.fileno
    my_env["WRITER_FD"] = writerfd.to_s
    pid = Kernel.spawn(my_env, "ruby " + SERVER_PATH + "VixDiskLibServer.rb",
                       [:out, :err]     => [LOG_FILE, "a"],
                       :unsetenv_others => true,
                       :close_others    => false,
                       reader           => :close
                       )
    writer.close
    Process.detach(pid)
    $vim_log.info "Process #{pid} started as VixDiskLibServer"
    DRb.start_service
    retry_limit = 5
    begin
      sleep 1
      if reader.eof
        #
        # Error - unable to read the port number written into the pipe by the child (Server).
        #
        raise VixDiskLibError, "ERROR: VixDiskLibClient.connect() Unable to determine port used by VixDiskLib Server."
      end
      uri_input = reader.gets
      uri_selected = uri_input.split("URI:")
      if uri_selected.length != 2
        raise VixDiskLibError, "ERROR: VixDiskLibClient.connect() Unable to determine port used by VixDiskLib Server."
      end
      uri = uri_selected[1].chomp
      @vix_disk_lib_service = DRbObject.new(nil, uri)
    rescue DRb::DRbConnError => e
      if retry_limit > 0
        retry_limit -= 1
        retry
      else
        $vim_log.error "VixDiskLibError: VixDiskLibClient.connect() got #{connect_failed} on DRbObject.new_with_uri()"
        raise VixDiskLibError, "ERROR: VixDiskLibClient.connect() got #{connect_failed} on DRbObject.new_with_uri()"
      end
    end
    #
    # Let the DRb service start before attempting to use it.
    # I can find no examples suggesting that this is required, but on my test machine it is indeed.
    #
    retry_limit = 5
    begin
      sleep 1
      @vix_disk_lib_service.init(@init_parms[:info], @init_parms[:warn], @init_parms[:error], @init_parms[:lib_dir])
    rescue DRb::DRbConnError => e
      if retry_limit > 0
        $vim_log.info "#{e}: sleeping 1 second before trying to use the DRbObject again"
        sleep 1
        retry_limit -= 1
        retry
      else
        $vim_log.error "VixDiskLibError: VixDiskLibClient.connect() failed: #{e} on VixDiskLib.init()"
        raise VixDiskLibError, "VixDiskLibClient.connect() failed: #{e} on VixDiskLib.init()"
      end
    end
    connection = @vix_disk_lib_service.connect(connect_parms)
    connection
  end

  def self.exit
    unless @vix_disk_lib_service.nil?
      DRb.stop_service
      @vix_disk_lib_service.shutdown = true
      @vix_disk_lib_service = nil
    end
  end

  private

  #
  # Remove the Rails Environment Variables set in the Current Environment so that the SSL Libraries don't get loaded.
  #
  def self.setup_env
    vars_to_clear = %w(BUNDLE_BIN
                       BUNDLE_BIN_PATH
                       BUNDLE_GEMFILE
                       BUNDLE_ORIG_MANPATH
                       EVMSERVER
                       GEM_HOME
                       GEM_PATH
                       MIQ_GUID
                       RAILS_ENV
                       RUBYOPT
                       ORIGINAL_GEM_PATH)
    my_env = ENV.to_hash
    vars_to_clear.each do |key|
      my_env.delete(key)
    end
    my_env
  end
end
