module ProviderConfigurationManagerHelper
  def textual_group_properties
    %i(hostname
       ipmi_present
       ipaddress
       mac_address
       provider_name
       zone)
  end

  def textual_hostname
    {:label => _("Hostname"),
     :image => "configured_system",
     :value => @record.hostname,
    }
  end

  def textual_ipmi_present
    {:label => _("IPMI Present"), :value => @record.ipmi_present}
  end

  def textual_ipaddress
    {:label => _("IP Address"), :value => @record.ipaddress}
  end

  def textual_mac_address
    {:label => _("Mac address"), :value => @record.mac_address}
  end

  def textual_provider_name
    {:label    => _("Provider"),
     :image    => "vendor-#{@record.configuration_manager.image_name}",
     :value    => @record.configuration_manager.try(:name),
     :explorer => true
    }
  end

  def textual_zone
    {:label => _("Zone"), :value => @record.configuration_manager.my_zone}
  end

  def textual_group_tags
    %i(tags)
  end
end
