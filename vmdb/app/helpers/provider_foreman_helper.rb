module ProviderForemanHelper
  def textual_group_properties
    items = %w(hostname configuration_profile configuration_profile_desc provider provider_url zone)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  def textual_hostname
    {:label => "Host Name", :value => @record.hostname}
  end

  def textual_configuration_profile
    {:label => "Configuration Profile", :value => @record.configuration_profile.try(:name)}
  end

  def textual_configuration_profile_desc
    {:label => "Configuration Profile Description", :value => @record.configuration_profile.try(:description)}
  end

  def textual_provider
    {:label => "Foreman Provider", :value => @record.configuration_manager.provider.name}
  end

  def textual_provider_url
    {:label => "Foreman Provider URL", :value => @record.configuration_manager.provider.url}
  end

  def textual_zone
    {:label => "Zone", :value => @record.configuration_manager.my_zone}
  end
end
