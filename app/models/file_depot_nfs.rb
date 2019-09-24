class FileDepotNfs < FileDepot
  def self.requires_credentials?
    false
  end

  def self.uri_prefix
    "nfs"
  end
end
