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
    begin
      connection = connect(_options)

      # Not all errors will cause Fog to raise an exception,
      # for example an error in the google_project id will
      # succeed to connect but the first API call will raise
      # an exception, so make a simple call to the API to
      # confirm everything is working
      connection.regions.all
    rescue => err
      raise MiqException::MiqInvalidCredentialsError, err.message
    end

    true
  end

  #
  # Connections
  #

  def connect(_options = {})
    require 'fog/google'

    raise MiqException::MiqHostError, "No credentials defined" if self.missing_credentials?(:service_account)

    service_account = authentication_service_account(:service_account)

    options = {
      :provider               => "Google",
      :google_project         => project,
      :google_json_key_string => service_account,
    }

    ::Fog::Compute.new(options)
  end

  def gce
    @gce ||= connect(:service => "GCE")
  end
end
