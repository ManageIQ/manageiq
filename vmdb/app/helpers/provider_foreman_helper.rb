module ProviderForemanHelper
  def textual_group_properties
    @configuration_manager_foreman = ConfigurationManagerForeman.find(@record.configuration_manager_id)
    items = %w(hostname configuration_profile configuration_profile_desc provider provider_url zone)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  def textual_hostname
    {:label => "Host Name", :value => @record.hostname}
  end

  def textual_configuration_profile
    {:label => "Configuration Profile",
     :value => ConfigurationProfile.find(@record.configuration_profile_id).name}
  end

  def textual_configuration_profile_desc
    {:label => "Configuration Profile Description",
     :value => ConfigurationProfile.find(@record.configuration_profile_id).description}
  end

  def textual_provider
    {:label => "Foreman Provider",
     :value => ProviderForeman.find(@configuration_manager_foreman.provider_id).name}
  end

  def textual_provider_url
    {:label => "Foreman Provider URL",
     :value => ProviderForeman.find(@configuration_manager_foreman.provider_id).url}
  end

  def textual_zone
    {:label => "Zone", :value => Zone.find(@configuration_manager_foreman.zone_id).name}
  end
end
