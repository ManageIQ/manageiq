class ProviderForeman < Provider
  has_one :configuration_manager,
          :foreign_key => "provider_id",
          :class_name  => "ConfigurationManagerForeman",
          :dependent   => :destroy,
          :autosave    => true
  has_one :provisioning_manager,
          :foreign_key => "provider_id",
          :class_name  => "ProvisioningManagerForeman",
          :dependent   => :destroy,
          :autosave    => true

  before_validation :ensure_managers

  validates :name, :presence => true, :uniqueness => true

  def self.ems_type
    @ems_type ||= "foreman".freeze
  end

  def self.raw_connect(base_url, username, password, verify_ssl)
    require 'manageiq_foreman'
    ManageiqForeman::Connection.new(
      :base_url   => base_url,
      :username   => username,
      :password   => password,
      :verify_ssl => verify_ssl
    )
  end

  def connect(options = {})
    auth_type = options[:auth_type]
    raise "no credentials defined" if self.missing_credentials?(auth_type)

    verify_ssl = resolve_verify_ssl_value(options[:verify_ssl]) || self.verify_ssl
    base_url   = options[:url]      || url
    username   = options[:username] || authentication_userid(auth_type)
    password   = options[:password] || authentication_password(auth_type)

    self.class.raw_connect(base_url, username, password, verify_ssl)
  end

  def verify_credentials(auth_type = nil, options = {})
    with_provider_connection(options.merge(:auth_type => auth_type), &:verify?)
  rescue SocketError => err
    raise MiqException::MiqUnreachableError, err.message, err.backtrace
  rescue RestClient::Unauthorized => err
    raise MiqException::MiqInvalidCredentialsError, err.message, err.backtrace if err.http_code == 401 # Unauthorized
    raise MiqException::MiqUnreachableError, err.message, err.backtrace        if err.http_code == 404 # Resource Not Found
    raise
  end

  private

  def ensure_managers
    build_provisioning_manager unless provisioning_manager
    provisioning_manager.name    = "#{name} Provisioning Manager"
    provisioning_manager.zone_id = zone_id

    build_configuration_manager unless configuration_manager
    configuration_manager.name    = "#{name} Configuration Manager"
    configuration_manager.zone_id = zone_id
  end
end
