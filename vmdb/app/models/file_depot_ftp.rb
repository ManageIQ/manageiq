require 'net/ftp'

class FileDepotFtp < FileDepot
  def upload_file(file)
    super
    log_header = "MIQ(#{self.class.name}##{__method__})"

    begin
      ftp = connect
      create_directory_structure(ftp)

      if destination_file_exists?(ftp, destination_file)
        $log.info("#{log_header} Found file: #{file} on server... skipping")
      else
        $log.info("#{log_header} Uploading file: #{file} to File Depot: #{name}...")
        ftp.putbinaryfile(file.local_file, destination_file)
        file.update_attributes(:log_uri => destination_file)
        $log.info("#{log_header} Uploading file: #{file}... Complete")
      end
    rescue => err
      msg = "Error '#{err.message.chomp}', writing to FTP: [#{uri}], Username: [#{authentication_userid}]"
      $log.error("#{log_header} #{msg}")
      raise msg
    ensure
      ftp.try(:close)
    end
  end

  private

  def connect
    log_header = "MIQ(#{self.class.name}##{__method__})"
    host       = URI.split(URI.encode(uri))[2]

    begin
      $log.info("#{log_header} Connecting to #{self.class.name}: #{name} host: #{host}...")
      ftp         = Net::FTP.new(host)
      ftp.passive = true  # Use passive mode to avoid firewall issues see http://slacksite.com/other/ftp.html#passive
      # ftp.debug_mode = true if settings[:debug]  # TODO: add debug option
      ftp.login(authentication_userid, authentication_password)
      $log.info("#{log_header} Connected to #{self.class.name}: #{name}")
    rescue SocketError => err
      $log.error("#{log_header} Failed to connect.  #{err.message}")
      raise
    rescue Net::FTPPermError => err
      $log.error("#{log_header} Failed to login.  #{err.message}")
      raise
    else
      ftp
    end

  end

  def create_directory_structure(ftp)
    $log.info("MIQ(#{self.class.name}##{__method__}) Creating directory structure on server...")
    ftp.mkdir(destination_path)
  rescue Net::FTPPermError => err
    return if err.message.to_s.strip.start_with?("521")  # path already exists.
    raise
  end

  def destination_file_exists?(ftp, file)
    $log.info("MIQ(#{self.class.name}##{__method__}) Checking for log file #{file} on server...")
    result = ftp.ls(file).present?
    $log.info("MIQ(#{self.class.name}##{__method__}) Found file: #{file} on server... skipping") if result
    result
  end

  def destination_file
    @destination_file ||= File.join(destination_path, file.destination_file_name)
  end

  def destination_path
    @destination_path ||= File.join(base_path, file.destination_directory)
  end

  def base_path
    # URI.split(URI.encode("ftp://ftp.example.com/incoming"))[5]  => "/incoming"
    URI.split(URI.encode(uri))[5]
  end
end
