class FileDepotSmb < FileDepot
  DISPLAY_NAME = "Samba"

  def self.uri_prefix
    "smb"
  end
end
