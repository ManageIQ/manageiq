class ProviderForeman < Provider
  has_one :configuration_manager, :class_name => :ConfigurationManagerForeman
  has_one :provisioning_manager, :class_name => :ProvisionManagerForeman
  has_many :operating_system_flavors
  has_many :configuration_profiles

  def connection_attrs
    {
      :base_url   => url,
      :username   => authentication_userid,
      :password   => authentication_password,
      :verify_ssl => verify_ssl
    }
  end
end
