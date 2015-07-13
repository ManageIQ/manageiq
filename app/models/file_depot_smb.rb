require 'mount/miq_generic_mount_session'

class FileDepotSmb < FileDepot
  def self.uri_prefix
    "smb"
  end

  def self.validate_settings(settings)
    res = MiqSmbSession.new(settings).verify
    raise "Depot Settings validation failed with error: #{res.last}" unless res.first
    res
  end

  def verify_credentials(_auth_type = nil, cred_hash = nil)
    self.class.validate_settings(cred_hash.merge(:uri => uri))
  end
end
