require 'net/ftp'

class FileDepotFtp < FileDepot
  attr_accessor :ftp

  def self.uri_prefix
    "ftp"
  end

  def log_header(method = nil)
    "MIQ(#{self.class.name}##{method})"
  end

  def self.validate_settings(settings)
    depot = new(:uri => settings[:uri])
    depot.with_connection(:username => settings[:username], :password => settings[:password]) { |c| c.last_response }
  end

  def upload_file(file)
    super
    with_connection do
      begin
        return if file_exists?(destination_file)

        upload(file.local_file, destination_file)
      rescue => err
        msg = "Error '#{err.message.chomp}', writing to FTP: [#{uri}], Username: [#{authentication_userid}]"
        $log.error("#{log_header(__method__)} #{msg}")
        raise msg
      else
        file.update_attributes(
          :state   => "available",
          :log_uri => destination_file
        )
        file.post_upload_tasks
      end
    end
  end

  def remove_file(file)
    @file = file
    $log.info("#{log_header(__method__)} Removing log file [#{destination_file}]...")
    with_connection do |ftp|
      ftp.delete(destination_file.to_s)
    end
    $log.info("#{log_header(__method__)} Removing log file [#{destination_file}]...complete")
  end

  def verify_credentials(_auth_type = nil)
    with_connection(&:last_response)
  rescue
    false
  end

  def with_connection(cred_hash = nil)
    raise "no block given" unless block_given?
    $log.info("MIQ(#{self.class.name}##{__method__}) Connecting through #{self.class.name}: [#{name}]")
    begin
      connection = connect(cred_hash)
      @ftp = connection
      yield connection
    ensure
      connection.try(:close)
      @ftp = nil
    end
  end

  def connect(cred_hash = nil)
    host       = URI.split(URI.encode(uri))[2]

    begin
      $log.info("#{log_header(__method__)} Connecting to #{self.class.name}: #{name} host: #{host}...")
      @ftp         = Net::FTP.new(host)
      @ftp.passive = true  # Use passive mode to avoid firewall issues see http://slacksite.com/other/ftp.html#passive
      # @ftp.debug_mode = true if settings[:debug]  # TODO: add debug option
      creds = cred_hash ? [cred_hash[:username], cred_hash[:password]] : login_credentials
      @ftp.login(*creds)
      $log.info("#{log_header(__method__)} Connected to #{self.class.name}: #{name} host: #{host}")
    rescue SocketError => err
      $log.error("#{log_header(__method__)} Failed to connect.  #{err.message}")
      raise
    rescue Net::FTPPermError => err
      $log.error("#{log_header(__method__)} Failed to login.  #{err.message}")
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

  def create_directory_structure(directory_path)
    Pathname.new(directory_path).descend do |path|
      next if file_exists?(path)

      $log.info("#{log_header(__method__)} creating #{path}")
      ftp.mkdir(path.to_s)
    end
  end

  def upload(source, destination)
    create_directory_structure(destination_path)
    $log.info("#{log_header(__method__)} Uploading file: #{destination} to File Depot: #{name}...")
    ftp.putbinaryfile(source, destination.to_s)
    $log.info("#{log_header(__method__)} Uploading file: #{destination_file}... Complete")
  end

  def destination_file
    destination_path.join(file.destination_file_name).to_s
  end

  def destination_path
    base_path.join(file.destination_directory)
  end

  def base_path
    # uri: "ftp://ftp.example.com/incoming" => #<Pathname:incoming>
    path = URI(URI.encode(uri)).path
    Pathname.new(path)
  end

  def login_credentials
    [authentication_userid, authentication_password]
  end
end

VMDB::Util.eager_load_subclasses('FileDepotFtp')
