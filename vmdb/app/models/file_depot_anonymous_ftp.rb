class FileDepotAnonymousFtp < FileDepotFtp
  DISPLAY_NAME = "Anonymous FTP"

  def remove_file(_file)
    $log.info("MIQ(#{self.class.name}##{__method__}) Removing log file not supported on this depot type")
  end

  private

  def create_directory_structure(_ftp)
    nil
  end

  def destination_file_exists?(_ftp, _file)
    false
  end

  def destination_path
    "/incoming"
  end

  def login_credentials
    ["anonymous", "anonymous"]
  end
end
