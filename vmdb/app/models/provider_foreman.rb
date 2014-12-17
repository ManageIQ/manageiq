class ProviderForeman < Provider
  has_one :configuration_service, :class_name => :ConfigurationServiceForeman
  has_many :operating_system_flavors
  has_many :configuration_profiles
  has_many :configured_systems, :class_name => :ConfiguredSystemForemans

  def connection_attrs
    {
      :base_url   => port ? "#{hostname}:#{port}" : hostname,
      :username   => authentication_userid,
      :password   => authentication_password,
      :verify_ssl => verify_ssl
    }
  end
end
