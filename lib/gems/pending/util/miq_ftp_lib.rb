require 'net/ftp'

# Helper methods for net/ftp based classes and files.
#
# Will setup a `@ftp` attr_accessor to be used as the return value for
# `.connect`, the main method being provided in this class.
module MiqFtpLib
  def self.included(klass)
    klass.send(:attr_accessor, :ftp)
  end

  def connect(cred_hash = nil)
    host = URI(uri).hostname

    begin
      _log.info("Connecting to FTP host #{host_ref}...")
      @ftp         = Net::FTP.new(host)
      # Use passive mode to avoid firewall issues see http://slacksite.com/other/ftp.html#passive
      @ftp.passive = true
      # @ftp.debug_mode = true if settings[:debug]  # TODO: add debug option
      creds = cred_hash ? [cred_hash[:username], cred_hash[:password]] : login_credentials
      @ftp.login(*creds)
      _log.info("Successfully connected FTP host #{host_ref}...")
    rescue SocketError => err
      _log.error("Failed to connect.  #{err.message}")
      raise
    rescue Net::FTPPermError => err
      _log.error("Failed to login.  #{err.message}")
      raise
    else
      @ftp
    end
  end

  def file_exists?(file_or_directory)
    !ftp.nlst(file_or_directory.to_s).empty?
  rescue Net::FTPPermError
    false
  end

  private

  def host_ref
    return @host_ref if @host_ref
    @host_ref = URI(uri).hostname
    @host_ref << " (#{name})" if respond_to?(:name)
    @host_ref
  end

  def create_directory_structure(directory_path)
    pwd = ftp.pwd
    directory_path.to_s.split('/').each do |directory|
      unless ftp.nlst.include?(directory)
        _log.info("creating #{directory}")
        ftp.mkdir(directory)
      end
      ftp.chdir(directory)
    end
    ftp.chdir(pwd)
  end

  def with_connection(cred_hash = nil)
    raise _("no block given") unless block_given?
    _log.info("Connecting through #{self.class.name}: [#{host_ref}]")
    begin
      connect(cred_hash)
      yield @ftp
    ensure
      @ftp.try(:close) && @ftp = nil
    end
  end
end
