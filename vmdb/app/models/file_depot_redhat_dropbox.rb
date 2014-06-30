class FileDepotRedhatDropbox < FileDepotFtp
  default_value_for :uri, "ftp://dropbox.redhat.com"

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

  def destination_file
    @destination_file ||= begin
      file_name = [support_case, file.destination_file_name].delete_blanks.join("-")
      File.join(destination_path, file_name)
    end
  end

  def destination_path
    "/incoming"
  end

  def login_credentials
    ["anonymous", "anonymous"]
  end

  def requires_credentials?
    false
  end
end
