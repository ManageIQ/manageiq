require 'net/ftp'

class FileDepotFtp < FileDepot
  attr_accessor :ftp

  def self.uri_prefix
    "ftp"
  end

  def self.validate_settings(settings)
    new(:uri => settings[:uri]).verify_credentials(nil, settings.slice(:username, :password))
  end

  def upload_file(file)
    super
    with_connection do
      begin
        return if file_exists?(destination_file)

        upload(file.local_file, destination_file)
      rescue => err
        msg = "Error '#{err.message.chomp}', writing to FTP: [#{uri}], Username: [#{authentication_userid}]"
        _log.error(msg)
        raise _("Error '%{message}', writing to FTP: [%{uri}], Username: [%{id}]") % {:message => err.message.chomp,
                                                                                      :uri     => uri,
                                                                                      :id      => authentication_userid}
      else
        file.update(
          :state   => "available",
          :log_uri => destination_file
        )
        file.post_upload_tasks
      end
    end
  end

  def remove_file(file)
    @file = file
    _log.info("Removing log file [#{destination_file}]...")
    with_connection do |ftp|
      ftp.delete(destination_file.to_s)
    end
    _log.info("Removing log file [#{destination_file}]...complete")
  end

  def verify_credentials(_auth_type = nil, cred_hash = nil)
    res = with_connection(cred_hash, &:last_response)
    raise _("Depot Settings validation failed") unless res
    res
  end

  def with_connection(cred_hash = nil)
    raise _("no block given") unless block_given?
    _log.info("Connecting through #{self.class.name}: [#{name}]")
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
    host = URI(uri).hostname

    begin
      _log.info("Connecting to #{self.class.name}: #{name} host: #{host}...")
      @ftp         = Net::FTP.new(host)
      @ftp.passive = true  # Use passive mode to avoid firewall issues see http://slacksite.com/other/ftp.html#passive
      # @ftp.debug_mode = true if settings[:debug]  # TODO: add debug option
      creds = cred_hash ? [cred_hash[:username], cred_hash[:password]] : login_credentials
      @ftp.login(*creds)
      _log.info("Connected to #{self.class.name}: #{name} host: #{host}")
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

  def self.display_name(number = 1)
    n_('FTP', 'FTPs', number)
  end

  private

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

  def upload(source, destination)
    create_directory_structure(destination_path)
    _log.info("Uploading file: #{destination} to File Depot: #{name}...")
    ftp.putbinaryfile(source, destination.to_s)
    _log.info("Uploading file: #{destination_file}... Complete")
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
