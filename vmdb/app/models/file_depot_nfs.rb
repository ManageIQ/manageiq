class FileDepotNfs < FileDepot
  DISPLAY_NAME = "NFS"

  def self.uri_prefix
    "nfs"
  end
end
