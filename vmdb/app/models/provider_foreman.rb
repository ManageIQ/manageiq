class ProviderForeman < Provider
  has_one :configuration_manager, :class_name => "ConfigurationManagerForeman"
  has_one :provisioning_manager, :class_name => "ProvisionManagerForeman"

  has_many :operating_system_flavors, :foreign_key => "provider_id"
  has_many :configuration_profiles,   :foreign_key => "provider_id"
  has_many :customization_scripts,    :foreign_key => "provider_id"

  has_many :medium_scripts,
           :foreign_key => "provider_id",
           :primary_key => "customization_script_id",
           :class_name  => "CustomizationScriptMedium",
           :conditions  => { :type => "CustomizationScriptMedium" }

  has_many :ptable_scripts,
           :foreign_key => "provider_id",
           :primary_key => "customization_script_id",
           :class_name  => "CustomizationScriptPtable",
           :conditions  => { :type => "CustomizationScriptPtable" }

  has_many :configured_systems,
           :foreign_key => "provider_id",
           :class_name  => "ConfiguredSystemForeman"

  def connection_attrs
    {
      :base_url   => url,
      :username   => authentication_userid,
      :password   => authentication_password,
      :verify_ssl => verify_ssl
    }
  end
end
