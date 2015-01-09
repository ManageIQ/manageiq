class ProviderForeman < Provider
  has_one :configuration_manager, :class_name => "ConfigurationManagerForeman", :dependent => :destroy
  has_one :provisioning_manager,  :class_name => "ProvisioningManagerForeman",     :dependent => :destroy

  def before_save
    build_provisioning_manager unless provisioning_manager
    build_configuration_manager unless configuration_manager
  end

  def connection_attrs
    {
      :base_url   => url,
      :username   => authentication_userid,
      :password   => authentication_password,
      :verify_ssl => verify_ssl
    }
  end
end
