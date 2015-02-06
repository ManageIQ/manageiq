class FileDepotFtpAnonymous < FileDepotFtp
  def self.requires_credentials?
    false
  end

  def remove_file(_file)
    $log.info("MIQ(#{self.class.name}##{__method__}) Removing log file not supported on this depot type")
  end

  private

  def create_directory_structure(_path)
    nil
  end

  def file_exists?(_file)
    false
  end

  def destination_path
    Pathname.new("incoming")
  end

  def login_credentials
    ["anonymous", "anonymous"]
  end
end
