require 'active_support/core_ext/object/blank'
require 'fileutils'
require 'logger'
require 'sys-uname'
require 'uri'

require 'util/miq-exception'
require 'util/miq-uuid'

class MiqGenericMountSession
  require 'util/mount/miq_nfs_session'
  require 'util/mount/miq_smb_session'
  require 'util/mount/miq_glusterfs_session'

  attr_accessor :settings, :mnt_point, :logger

  def initialize(log_settings)
    raise "URI missing" unless log_settings.key?(:uri)
    @settings  = log_settings.dup
    @mnt_point = nil
  end

  def logger
    @logger ||= $log.nil? ? :: Logger.new(STDOUT) : $log
  end

  def runcmd(cmd_str)
    self.class.runcmd(cmd_str)
  end

  def self.runcmd(cmd_str)
    rv = `#{cmd_str} 2>&1`

    # If sudo is required, ensure you have /etc/sudoers.d/miq
    # Cmnd_Alias MOUNTALL = /bin/mount, /bin/umount
    # %wheel ALL = NOPASSWD: MOUNTALL
    rv = `sudo #{cmd_str} 2>&1` if rv.include?("mount: only root can do that")

    if $? != 0
      raise rv
    end
  end

  def self.in_depot_session(opts, &_block)
    raise "No block provided!" unless block_given?
    session = new_session(opts)
    yield session
  ensure
    session.disconnect if session
  end

  def self.new_session(opts)
    klass = uri_scheme_to_class(opts[:uri])
    session = klass.new(:uri => opts[:uri], :username => opts[:username], :password => opts[:password])
    session.connect
    session
  end

  def self.uri_scheme_to_class(uri)
    require 'uri'
    scheme, userinfo, host, port, registry, share, opaque, query, fragment = URI.split(URI.encode(uri))
    case scheme
    when 'smb'
      MiqSmbSession
    when 'nfs'
      MiqNfsSession
    when 'glusterfs'
      MiqGlusterfsSession
    else
      raise "unsupported scheme #{scheme} from uri: #{uri}"
    end
  end

  def mount_share
    require 'tmpdir'
    @mnt_point = settings_mount_point || Dir.mktmpdir("miq_")
  end

  def get_ping_depot_options
    @@ping_depot_options ||= begin
      opts = ::VMDB::Config.new("vmdb").config[:log][:collection] if defined?(::VMDB) && defined?(::VMDB::CONFIG)
      opts = {:ping_depot => false}
      opts
    end
  end

  def ping_timeout
    get_ping_depot_options
    @@ping_timeout ||= (@@ping_depot_options[:ping_depot_timeout] || 20)
  end

  def do_ping?
    get_ping_depot_options
    @@do_ping ||= @@ping_depot_options[:ping_depot] == true
  end

  def pingable?
    log_header = "MIQ(#{self.class.name}-pingable?)"
    return true unless self.do_ping?
    return true unless @settings[:ports].kind_of?(Array)

    res = false
    require 'net/ping'
    begin
      # To prevent "no route to host" type issues, assume refused connection indicates the host is reachable
      before = Net::Ping::TCP.econnrefused
      Net::Ping::TCP.econnrefused = true

      @settings[:ports].each do |port|
        logger.info("#{log_header} pinging: #{@host} on #{port} with timeout: #{ping_timeout}")
        tcp1 = Net::Ping::TCP.new(@host, port, ping_timeout)
        res = tcp1.ping
        logger.info("#{log_header} pinging: #{@host} on #{port} with timeout: #{ping_timeout}...result: #{res}")
        break if res == true
      end
    ensure
      Net::Ping::TCP.econnrefused = before
    end

    res == true
  end

  def connect
    log_header = "MIQ(#{self.class.name}-connect)"

    # Replace any encoded spaces back into spaces since the mount commands accepts quoted spaces
    @mount_path = @mount_path.to_s.gsub('%20', ' ')

    #    # Grab only the share part of a path such as: /temp/default_1/evm_1/current_default_1_evm_1_20091120_192429_20091120_225653.zip
    #    @mount_path = @mount_path.split("/")[0..1].join("/")

    begin
      raise "Connect: Cannot communicate with: #{@host} - verify the URI host value and your DNS settings" unless self.pingable?

      mount_share
    rescue MiqException::MiqLogFileMountPointMissing => err
      logger.warn("#{log_header} Connecting to host: [#{@host}], share: [#{@mount_path}] encountered error: [#{err.class.name}] [#{err.message}]...retrying after disconnect")
      disconnect
      retry
    rescue => err
      if err.kind_of?(RuntimeError) && err.message =~ /No such file or directory/
        msg = "No such file or directory when connecting to host: [#{@host}] share: [#{@mount_path}]"
        raise MiqException::MiqLogFileNoSuchFileOrDirectory, msg
      end
      msg = "Connecting to host: [#{@host}], share: [#{@mount_path}] encountered error: [#{err.class.name}] [#{err.message}]"
      logger.error("#{log_header} #{msg}...#{err.backtrace.join("\n")}")
      disconnect
      raise
    end
  end

  def disconnect
    self.class.disconnect(@mnt_point, logger)
    @mnt_point = nil
  end

  def self.disconnect(mnt_point, logger = $log)
    return if mnt_point.nil?
    log_header = "MIQ(#{self.class.name}-disconnect)"
    logger.info("#{log_header} Disconnecting mount point: #{mnt_point}") if logger
    begin
      raw_disconnect(mnt_point)
    rescue => err
      # Ignore mount point not found/mounted messages
      unless err.message =~ /not found|mounted/
        msg = "[#{err.class.name}] [#{err.message}], disconnecting mount point: #{@mnt_point}"
        logger.error("#{log_header} #{msg}") if logger
        raise
      end
    end
    FileUtils.rmdir(mnt_point) if File.exist?(mnt_point)

    logger.info("#{log_header} Disconnecting mount point: #{mnt_point}...Complete") if logger
  end

  def active?
    !@mnt_point.nil?
  end

  def reconnect!
    disconnect
    connect
  end

  def with_test_file(&_block)
    raise "requires a block" unless block_given?
    file = '/tmp/miq_verify_test_file'
    begin
      `echo "testing" > #{file}`
      yield file
    ensure
      FileUtils.rm(file, :force => true)
    end
  end

  def verify
    log_header = "MIQ(#{self.class.name}-verify)"
    logger.info("#{log_header} [#{@settings[:uri]}]...")
    res = true

    begin
      connect
      relpath = File.join(@mnt_point, relative_to_mount(@settings[:uri]))

      test_path = 'miqverify/test'
      to = File.join(test_path, 'test_file')
      fq_file_path = File.join(relpath, to)

      current_test = "create nested directories"
      logger.info("#{log_header} [#{@settings[:uri]}] Testing #{current_test}...")
      FileUtils.mkdir_p(File.dirname(fq_file_path))
      logger.info("#{log_header} [#{@settings[:uri]}] Testing #{current_test}...complete")

      with_test_file do |from|
        current_test = "copy file"
        logger.info("#{log_header} [#{@settings[:uri]}] Testing #{current_test}...")
        FileUtils.cp(from, fq_file_path)
        logger.info("#{log_header} [#{@settings[:uri]}] Testing #{current_test}...complete")
      end

      current_test = "delete file"
      logger.info("#{log_header} [#{@settings[:uri]}] Testing #{current_test}...")
      FileUtils.rm(fq_file_path, :force => true)
      logger.info("#{log_header} [#{@settings[:uri]}] Testing #{current_test}...complete")

      current_test = "remove nested directories"
      logger.info("#{log_header} [#{@settings[:uri]}] Testing #{current_test}...")
      FileUtils.rmdir(File.dirname(fq_file_path))
      FileUtils.rmdir(File.dirname(File.dirname(fq_file_path)))
      logger.info("#{log_header} [#{@settings[:uri]}] Testing #{current_test}...complete")

    rescue => err
      logger.error("#{log_header} Verify [#{current_test}] failed with error [#{err.class.name}] [#{err}], [#{err.backtrace[0]}]")
      res = false, err.to_s
    else
      res = true, ""
    ensure
      disconnect
    end
    logger.info("#{log_header} [#{@settings[:uri]}]...result: [#{res.first}]")
    res
  end

  def add(source, dest_uri)
    log_header = "MIQ(#{self.class.name}-add)"

    logger.info("#{log_header} Source: [#{source}], Destination: [#{dest_uri}]...")

    begin
      reconnect!
      relpath = File.join(@mnt_point, relative_to_mount(dest_uri))
      if File.exist?(relpath)
        logger.info("#{log_header} Skipping add since URI: [#{dest_uri}] already exists")
        return dest_uri
      end

      logger.info("#{log_header} Building relative path: [#{relpath}]...")
      FileUtils.mkdir_p(File.dirname(relpath))
      logger.info("#{log_header} Building relative path: [#{relpath}]...complete")

      logger.info("#{log_header} Copying file [#{source}] to [#{relpath}]...")
      FileUtils.cp(source, relpath)
      logger.info("#{log_header} Copying file [#{source}] to [#{relpath}] complete")
    rescue => err
      msg = "Adding [#{source}] to [#{dest_uri}], failed due to error: '#{err.message}'"
      logger.error("#{log_header} #{msg}")
      raise
    ensure
      disconnect
    end

    logger.info("#{log_header} File URI added: [#{dest_uri}] complete")
    dest_uri
  end

  alias_method :upload, :add

  def download(local_file, remote_file)
    log_header = "MIQ(#{self.class.name}-download)"

    logger.info("#{log_header} Target: [#{local_file}], Remote file: [#{remote_file}]...")

    begin
      reconnect!
      relpath = File.join(@mnt_point, relative_to_mount(remote_file))
      unless File.exist?(relpath)
        logger.warn("#{log_header} Remote file: [#{remote_file}] does not exist!")
        return
      end

      logger.info("#{log_header} Copying file [#{relpath}] to [#{local_file}]...")
      FileUtils.cp(relpath, local_file)
      logger.info("#{log_header} Copying file [#{relpath}] to [#{local_file}] complete")
    rescue => err
      msg = "Downloading [#{remote_file}] to [#{local_file}], failed due to error: '#{err.message}'"
      logger.error("#{log_header} #{msg}")
      raise
    ensure
      disconnect
    end

    logger.info("#{log_header} Download File: [#{remote_file}] complete")
    local_file
  end

  def log_uri_still_configured?(log_uri)
    # Only remove the log file if the current depot @settings are based on the same base URI as the log_uri to be removed
    return false if log_uri.nil? || @settings[:uri].nil?

    scheme, userinfo, host, port, registry, share, opaque, query, fragment = URI.split(URI.encode(@settings[:uri]))
    scheme_log, userinfo_log, host_log, port_log, registry_log, share_log, opaque_log, query_log, fragment_log = URI.split(URI.encode(log_uri))

    return false if scheme != scheme_log
    return false if host != host_log

    # Since the depot URI is a base URI, remove all the directories in the log_uri from the base URI and check for empty?
    return false unless (share.split("/") - share_log.split("/")).empty?
    true
  end

  def remove(log_uri)
    log_header = "MIQ(#{self.class.name}-remove)"

    unless self.log_uri_still_configured?(log_uri)
      logger.info("#{log_header} Skipping remove because log URI: [#{log_uri}] does not originate from the currently configured base URI: [#{@settings[:uri]}]")
      return
    end

    relpath = nil
    begin
      # Samba has issues mount directly in the directory of the file so mount on the parent directory
      @settings.merge!(:uri => File.dirname(File.dirname(log_uri)))
      reconnect!

      relpath = File.join(@mnt_point, relative_to_mount(log_uri))
      # path is now /temp/default_1/EVM_1/Archive_default_1_EVM_1_20091016_193633_20091016_204855.zip, trim the share and join with the mount point
      # /mnt/miq_1258754934/default_1/EVM_1/Archive_default_1_EVM_1_20091016_193633_20091016_204855.zip
      # relpath = File.join(@mnt_point, path.split('/')[2..-1] )

      logger.info("#{log_header} URI: [#{log_uri}] using relative path: [#{relpath}] and mount path: [#{@mount_path}]...")

      unless File.exist?(relpath)
        logger.info("#{log_header} Skipping since URI: [#{log_uri}] with relative path: [#{relpath}] does not exist")
        return log_uri
      end

      logger.info("#{log_header} Deleting [#{relpath}] on [#{log_uri}]...")
      FileUtils.rm_rf(relpath)
      logger.info("#{log_header} Deleting [#{relpath}] on [#{log_uri}]...complete")
    rescue MiqException::MiqLogFileNoSuchFileOrDirectory => err
      logger.warn("#{log_header} No such file or directory to delete: [#{log_uri}]")
    rescue => err
      msg = "Deleting [#{relpath}] on [#{log_uri}], failed due to err '#{err.message}'"
      logger.error("#{log_header} #{msg}")
      raise
    ensure
      disconnect
    end

    logger.info("#{log_header} URI: [#{log_uri}]...complete")
    log_uri
  end

  def uri_to_local_path(remote_file)
    File.join(@mnt_point, relative_to_mount(remote_file))
  end

  def local_path_to_uri(local_path)
    relative_path = Pathname.new(local_path).relative_path_from(Pathname.new(@mnt_point)).to_s
    File.join(@settings[:uri], relative_path)
  end

  #
  # These methods require an existing connection
  #

  def glob(pattern)
    with_mounted_exception_handling do
      Dir.glob("#{mount_root}/#{pattern}").collect { |path| (path.split("/") - mount_root.split("/")).join("/") }
    end
  end

  def mkdir(path)
    with_mounted_exception_handling do
      FileUtils.mkdir_p("#{mount_root}/#{path}")
    end
  end

  def stat(file)
    with_mounted_exception_handling do
      File.stat("#{mount_root}/#{file}")
    end
  end

  def read(file)
    with_mounted_exception_handling do
      File.read("#{mount_root}/#{file}")
    end
  end

  def write(file, contents)
    with_mounted_exception_handling do
      mkdir(File.dirname(file))
      open(file, "w") { |fd| fd.write(contents) }
    end
  end

  def delete(file_or_directory)
    with_mounted_exception_handling do
      FileUtils.rm_rf("#{mount_root}/#{file_or_directory}")
    end
  end

  def open(*args, &block)
    with_mounted_exception_handling do
      args[0] = "#{mount_root}/#{args[0]}"
      File.open(*args, &block)
    end
  end

  def file?(file)
    with_mounted_exception_handling do
      File.file?("#{mount_root}/#{file}")
    end
  end

  protected

  def mount_root
    @mnt_point
  end

  def relative_to_mount(uri)
    log_header = "MIQ(#{self.class.name}-relative_to_mount)"
    logger.info("#{log_header} mount point [#{@mount_path}], uri: [#{uri}]...")
    scheme, userinfo, host, port, registry, path, opaque, query, fragment = URI.split(URI.encode(uri))

    # Replace any encoded spaces back into spaces since the mount commands accepts quoted spaces
    path.gsub!('%20', ' ')

    raise "path: #{path} or mount_path #{@mount_path} is blank" if path.nil? || @mount_path.nil? || path.empty? || @mount_path.empty?
    res = (path.split("/") - @mount_path.split("/")).join("/")
    logger.info("#{log_header} mount point [#{@mount_path}], uri: [#{uri}]...relative: [#{res}]")
    res
  end

  def with_mounted_exception_handling
    yield
  rescue => err
    err.message.gsub!(@mnt_point, @settings[:uri])
    raise
  end

  def self.raw_disconnect(mnt_point)
    case Sys::Platform::IMPL
    when :macosx
      runcmd("sudo umount #{mnt_point}")
    when :linux
      runcmd("umount #{mnt_point}")
    else
      raise "platform not supported"
    end
  end

  private

  def settings_read_only?
    @settings[:read_only] == true
  end

  def settings_mount_point
    return nil if @settings[:mount_point].blank? # Check if settings contains the mount_point to use
    FileUtils.mkdir_p(@settings[:mount_point]).first
  end
end
