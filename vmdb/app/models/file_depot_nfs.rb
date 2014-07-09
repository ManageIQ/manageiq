class FileDepotNfs < FileDepot
  DISPLAY_NAME = "NFS"

  def self.requires_credentials?
    false
  end

  def self.uri_prefix
    "nfs"
  end
end
