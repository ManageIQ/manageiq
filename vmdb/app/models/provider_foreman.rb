class ProviderForeman < Provider
  has_one :configuration_manager,
          :foreign_key => 'provider_id',
          :class_name => "ConfigurationManagerForeman",
          :dependent => :destroy
  has_one :provisioning_manager,
          :foreign_key => 'provider_id',
          :class_name => "ProvisioningManagerForeman",
          :dependent => :destroy

  before_create :build_managers

  def connection_attrs(auth_type = nil)
    {
      :base_url   => url,
      :username   => authentication_userid(auth_type),
      :password   => authentication_password(auth_type),
      :verify_ssl => verify_ssl
    }
  end

  private

  def build_managers
    build_provisioning_manager unless provisioning_manager
    build_configuration_manager unless configuration_manager
  end
end
