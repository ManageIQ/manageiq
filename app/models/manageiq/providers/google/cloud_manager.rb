class ManageIQ::Providers::Google::CloudManager < ManageIQ::Providers::CloudManager
  require_nested :Refresher

  attr_accessor :project

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
    %w(
      oauth
      service_account
    )
  end

  # TODO(lwander) determine if user wants to use OAUTH or a service account
  def missing_credentials?(_type)
    false
  end

  def supports_authentication?(authtype)
    supported_auth_types.include?(authtype.to_s)
  end

  validates :provider_region, :inclusion => {:in => ManageIQ::Providers::Google::Regions.names}

  def description
    ManageIQ::Providers::Google::Regions.find_by_name(provider_region)[:description]
  end

  def verify_credentials(auth_type = nil, _options = {})
    require 'fog/google'

    ::Fog::Compute.new(
      :provider => "Google",
      :google_project => project,
      :google_json_key_string => authentication_service_account(auth_type),
    )
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
