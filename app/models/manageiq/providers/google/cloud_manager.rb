class ManageIQ::Providers::Google::CloudManager < ManageIQ::Providers::CloudManager
  require_nested :Refresher

  def self.ems_type
    @ems_type ||= "gce".freeze
  end

  def self.description
    @description ||= "Google Compute Engine".freeze
  end

  def self.hostname_required?
    false
  end

  def self.region_required?
    false
  end

  def supported_auth_types
    %w(oauth)
  end

  def supports_authentication?(authtype)
    supported_auth_types.include?(authtype.to_s)
  end

  validates :provider_region, :inclusion => {:in => ManageIQ::Providers::Google::Regions.names}

  def description
    ManageIQ::Providers::Google::Regions.find_by_name(provider_region)[:description]
  end

  def verify_credentials(_auth_type = nil, _options = {})
    true
  end

  #
  # Connections
  #

  def connect(_options = {})
  end

  def gce
    @gce ||= connect(:service => "GCE")
  end
end
