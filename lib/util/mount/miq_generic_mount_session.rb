require 'active_support/core_ext/object/blank'
require 'fileutils'
require 'logger'
require 'platform'
require 'uri'

require_relative '../miq-exception'
require_relative '../miq-uuid'

$:.push(File.expand_path(File.join(File.dirname(__FILE__) ) ) )
require 'rubygems'

class MiqGenericMountSession
  #require 'miq_ftp_session'
  require 'miq_nfs_session'
  require 'miq_smb_session'

  attr_accessor :settings, :mnt_point, :logger

  def initialize(log_settings)
    @settings = log_settings.dup
    raise "URI missing" if @settings[:uri].nil?
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
    if $? != 0
      raise rv
    end
  end

  def self.in_depot_session(opts, &block)
    raise "No block provided!" unless block_given?
    session = self.new_session(opts)
    yield session
  ensure
    session.disconnect if session
  end

  def self.new_session(opts)
    klass = self.uri_scheme_to_class(opts[:uri])
    session = klass.new({:uri => opts[:uri], :username => opts[:username], :password => opts[:password]})
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
    else
      raise "unsupported scheme #{scheme} from uri: #{uri}"
    end
  end

  def mount_share
    # Check if settings contains the mount_point to use
    @mnt_point = @settings[:mount_point].blank? ? File.join(self.class.base_mount_point, "miq_#{MiqUUID.new_guid}") : @settings[:mount_point]
    raise MiqException::MountPointAlreadyExists, "#{@mnt_point} directory already exists!!!" if File.exist?(@mnt_point)

    FileUtils.mkdir_p @mnt_point
    raise MiqException::MiqLogFileMountPointMissing, "mount point: [#{@mnt_point}] failed to be created" unless File.directory?(@mnt_point)
  end

  def get_ping_depot_options
    @@ping_depot_options ||= begin
      opts = ::VMDB::Config.new("vmdb").config[:log][:collection] if defined?(::VMDB) && defined?(::VMDB::CONFIG)
      opts = {:ping_depot => false }
      opts
    end
  end

  def ping_timeout
    self.get_ping_depot_options
    @@ping_timeout ||= (@@ping_depot_options[:ping_depot_timeout] || 20)
  end

  def do_ping?
    self.get_ping_depot_options
    @@do_ping ||= @@ping_depot_options[:ping_depot] == true ? true : false
  end

  def pingable?
    log_header = "MIQ(#{self.class.name}-pingable?)"
    return true unless self.do_ping?
    return true unless @settings[:ports].is_a?(Array)

    res = false
    require 'net/ping'
    begin
      # To prevent "no route to host" type issues, assume refused connection indicates the host is reachable
      before = Net::Ping::TCP.econnrefused
      Net::Ping::TCP.econnrefused = true

      @settings[:ports].each do |port|
        self.logger.info("#{log_header} pinging: #{@host} on #{port} with timeout: #{self.ping_timeout}")
        tcp1 = Net::Ping::TCP.new(@host, port, self.ping_timeout)
        res = tcp1.ping
        self.logger.info("#{log_header} pinging: #{@host} on #{port} with timeout: #{self.ping_timeout}...result: #{res}")
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
    @mount_path = @mount_path.to_s.gsub('%20',' ')

    #    # Grab only the share part of a path such as: /temp/default_1/evm_1/current_default_1_evm_1_20091120_192429_20091120_225653.zip
    #    @mount_path = @mount_path.split("/")[0..1].join("/")

    begin
      raise "Connect: Cannot communicate with: #{@host} - verify the URI host value and your DNS settings" unless self.pingable?

      self.mount_share
    rescue MiqException::MiqLogFileMountPointMissing => err
      self.logger.warn("#{log_header} Connecting to host: [#{@host}], share: [#{@mount_path}] encountered error: [#{err.class.name}] [#{err.message}]...retrying after disconnect")
      self.disconnect
      retry
    rescue => err
      if err.is_a?(RuntimeError) && err.message =~ /No such file or directory/
        msg = "No such file or directory when connecting to host: [#{@host}] share: [#{@mount_path}]"
        raise MiqException::MiqLogFileNoSuchFileOrDirectory, msg
      end
      msg = "Connecting to host: [#{@host}], share: [#{@mount_path}] encountered error: [#{err.class.name}] [#{err.message}]"
      self.logger.error("#{log_header} #{msg}...#{err.backtrace.join("\n")}")
      self.disconnect
      raise
    end
  end

  def disconnect
    self.class.disconnect(@mnt_point, self.logger)
    @mnt_point = nil
  end

  def self.disconnect(mnt_point, logger=$log)
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
    self.disconnect
    self.connect
  end

  def with_test_file(&block)
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
    self.logger.info("#{log_header} [#{@settings[:uri]}]...")
    res = true

    begin
      self.connect
      relpath = File.join(@mnt_point, self.relative_to_mount(@settings[:uri]))

      test_path = 'miqverify/test'
      to= File.join(test_path, 'test_file')
      fq_file_path = File.join(relpath, to)

      current_test = "create nested directories"
      self.logger.info("#{log_header} [#{@settings[:uri]}] Testing #{current_test}...")
      FileUtils.mkdir_p(File.dirname(fq_file_path))
      self.logger.info("#{log_header} [#{@settings[:uri]}] Testing #{current_test}...complete")

      with_test_file do |from|
        current_test = "copy file"
        self.logger.info("#{log_header} [#{@settings[:uri]}] Testing #{current_test}...")
        FileUtils.cp(from, fq_file_path)
        self.logger.info("#{log_header} [#{@settings[:uri]}] Testing #{current_test}...complete")
      end

      current_test = "delete file"
      self.logger.info("#{log_header} [#{@settings[:uri]}] Testing #{current_test}...")
      FileUtils.rm(fq_file_path, :force => true)
      self.logger.info("#{log_header} [#{@settings[:uri]}] Testing #{current_test}...complete")

      current_test = "remove nested directories"
      self.logger.info("#{log_header} [#{@settings[:uri]}] Testing #{current_test}...")
      FileUtils.rmdir(File.dirname(fq_file_path))
      FileUtils.rmdir(File.dirname(File.dirname(fq_file_path)))
      self.logger.info("#{log_header} [#{@settings[:uri]}] Testing #{current_test}...complete")

    rescue => err
      self.logger.error("#{log_header} Verify [#{current_test}] failed with error [#{err.class.name}] [#{err.to_s}], [#{err.backtrace[0]}]")
      res = false, err.to_s
    else
      res = true, ""
    ensure
      disconnect
    end
    self.logger.info("#{log_header} [#{@settings[:uri]}]...result: [#{res.first}]")
    res
  end

  def add(source, dest_uri)
    log_header = "MIQ(#{self.class.name}-add)"

    self.logger.info("#{log_header} Source: [#{source}], Destination: [#{dest_uri}]...")

    begin
      reconnect!
      relpath = File.join(@mnt_point, self.relative_to_mount(dest_uri))
      if File.exist?(relpath)
        self.logger.info("#{log_header} Skipping add since URI: [#{dest_uri}] already exists")
        return dest_uri
      end

      self.logger.info("#{log_header} Building relative path: [#{relpath}]...")
      FileUtils.mkdir_p(File.dirname(relpath))
      self.logger.info("#{log_header} Building relative path: [#{relpath}]...complete")

      self.logger.info("#{log_header} Copying file [#{source}] to [#{relpath}]...")
      FileUtils.cp(source, relpath)
      self.logger.info("#{log_header} Copying file [#{source}] to [#{relpath}] complete")
    rescue => err
      msg = "Adding [#{source}] to [#{dest_uri}], failed due to error: '#{err.message}'"
      self.logger.error("#{log_header} #{msg}")
      raise
    ensure
      disconnect
    end

    self.logger.info("#{log_header} File URI added: [#{dest_uri}] complete")
    dest_uri
  end

  alias :upload :add

  def download(local_file, remote_file)
    log_header = "MIQ(#{self.class.name}-download)"

    self.logger.info("#{log_header} Target: [#{local_file}], Remote file: [#{remote_file}]...")

    begin
      reconnect!
      relpath = File.join(@mnt_point, self.relative_to_mount(remote_file))
      unless File.exist?(relpath)
        self.logger.warn("#{log_header} Remote file: [#{remote_file}] does not exist!")
        return
      end

      self.logger.info("#{log_header} Copying file [#{relpath}] to [#{local_file}]...")
      FileUtils.cp(relpath, local_file)
      self.logger.info("#{log_header} Copying file [#{relpath}] to [#{local_file}] complete")
    rescue => err
      msg = "Downloading [#{remote_file}] to [#{local_file}], failed due to error: '#{err.message}'"
      self.logger.error("#{log_header} #{msg}")
      raise
    ensure
      disconnect
    end

    self.logger.info("#{log_header} Download File: [#{remote_file}] complete")
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
    return true
  end

  def remove(log_uri)
    log_header = "MIQ(#{self.class.name}-remove)"

    unless self.log_uri_still_configured?(log_uri)
      self.logger.info("#{log_header} Skipping remove because log URI: [#{log_uri}] does not originate from the currently configured base URI: [#{@settings[:uri]}]")
      return
    end

    relpath = nil
    begin
      # Samba has issues mount directly in the directory of the file so mount on the parent directory
      @settings.merge!(:uri => File.dirname(File.dirname(log_uri) ) )
      reconnect!

      relpath = File.join(@mnt_point, self.relative_to_mount(log_uri))
      #path is now /temp/default_1/EVM_1/Archive_default_1_EVM_1_20091016_193633_20091016_204855.zip, trim the share and join with the mount point
      # /mnt/miq_1258754934/default_1/EVM_1/Archive_default_1_EVM_1_20091016_193633_20091016_204855.zip
      #relpath = File.join(@mnt_point, path.split('/')[2..-1] )

      self.logger.info("#{log_header} URI: [#{log_uri}] using relative path: [#{relpath}] and mount path: [#{@mount_path}]...")

      unless File.exist?(relpath)
        self.logger.info("#{log_header} Skipping since URI: [#{log_uri}] with relative path: [#{relpath}] does not exist")
        return log_uri
      end

      self.logger.info("#{log_header} Deleting [#{relpath}] on [#{log_uri}]...")
      FileUtils.rm_rf(relpath)
      self.logger.info("#{log_header} Deleting [#{relpath}] on [#{log_uri}]...complete")
    rescue MiqException::MiqLogFileNoSuchFileOrDirectory => err
      self.logger.warn("#{log_header} No such file or directory to delete: [#{log_uri}]")
    rescue => err
      msg = "Deleting [#{relpath}] on [#{log_uri}], failed due to err '#{err.message}'"
      self.logger.error("#{log_header} #{msg}")
      raise
    ensure
      disconnect
    end

    self.logger.info("#{log_header} URI: [#{log_uri}]...complete")
    log_uri
  end

  def uri_to_local_path(remote_file)
    File.join(@mnt_point, self.relative_to_mount(remote_file))
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
      Dir.glob("#{self.mount_root}/#{pattern}").collect { |path| (path.split("/") - self.mount_root.split("/")).join("/") }
    end
  end

  def mkdir(path)
    with_mounted_exception_handling do
      FileUtils.mkdir_p("#{self.mount_root}/#{path}")
    end
  end

  def stat(file)
    with_mounted_exception_handling do
      File.stat("#{self.mount_root}/#{file}")
    end
  end

  def read(file)
    with_mounted_exception_handling do
      File.read("#{self.mount_root}/#{file}")
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
      FileUtils.rm_rf("#{self.mount_root}/#{file_or_directory}")
    end
  end

  def open(*args, &block)
    with_mounted_exception_handling do
      args[0] = "#{self.mount_root}/#{args[0]}"
      File.open(*args, &block)
    end
  end

  def file?(file)
    with_mounted_exception_handling do
      File.file?("#{self.mount_root}/#{file}")
    end
  end

  protected

  def mount_root
    @mnt_point
  end

  def relative_to_mount(uri)
    log_header = "MIQ(#{self.class.name}-relative_to_mount)"
    self.logger.info("#{log_header} mount point [#{@mount_path}], uri: [#{uri}]...")
    scheme, userinfo, host, port, registry, path, opaque, query, fragment = URI.split(URI.encode(uri))

    # Replace any encoded spaces back into spaces since the mount commands accepts quoted spaces
    path.gsub!('%20',' ')

    raise "path: #{path} or mount_path #{@mount_path} is blank" if path.nil? || @mount_path.nil? || path.empty? || @mount_path.empty?
    res = (path.split("/") - @mount_path.split("/")).join("/")
    self.logger.info("#{log_header} mount point [#{@mount_path}], uri: [#{uri}]...relative: [#{res}]")
    res
  end

  def with_mounted_exception_handling
    yield
  rescue => err
    err.message.gsub!(@mnt_point, @settings[:uri])
    raise
  end

  def self.raw_disconnect(mnt_point)
    case Platform::IMPL
    when :macosx
      self.runcmd("sudo umount #{mnt_point}")
    when :linux
      self.runcmd("umount #{mnt_point}")
    else
      raise "platform not supported"
    end
  end

  def self.base_mount_point
    case Platform::IMPL
    when :macosx
      "/Volumes"
    when :linux
      "/mnt"
    else
      raise "platform not supported"
    end
  end
end