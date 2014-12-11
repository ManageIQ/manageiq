class FileDepotSmb < FileDepot
  def self.uri_prefix
    "smb"
  end

  def self.validate_settings(settings)
    res = MiqSmbSession.new(settings).verify
    raise "Log Depot Settings validation failed with error: #{res.last}" unless res.first
    res
  end
end
