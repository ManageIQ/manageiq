class FileDepotNfs < FileDepot
  def self.requires_credentials?
    false
  end

  def self.uri_prefix
    "nfs"
  end

  def self.display_name(number = 1)
    n_('NFS', 'NFS', number)
  end
end
