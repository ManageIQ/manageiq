module ProviderForemanHelper
  def textual_group_properties
    [textual_hostname,
     textual_ipmi_present,
     textual_ipaddress,
     textual_mac_address,
     textual_configuration_profile_desc,
     textual_provider_name,
     textual_zone].flatten.compact
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

  def textual_configuration_profile_desc
    h = {
      :label    => _("Configuration Profile Description"),
      :value    => @record.configuration_profile.try(:description),
      :explorer => true
    }
    h[:image] = "configuration_profile" if @record.configuration_profile
    h
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
    [textual_tags].flatten.compact
  end

  def textual_tags
    label = _("%s Tags") % session[:customer_name]
    h = {:label => label}
    tags = session[:assigned_filters]
    if tags.empty?
      h[:image] = "smarttag"
      h[:value] = "No #{label} have been assigned"
    else
      h[:value] =
        tags.sort_by { |category, _assigned| category.downcase }.collect { |category, assigned| {:image => "smarttag", :label => category, :value => assigned} }
    end
    h
  end

  def textual_group_environment
    [textual_configuration_environment_name,
     textual_configuration_domain_name,
     textual_configuration_realm_name].flatten.compact
  end

  def textual_configuration_environment_name
    {:label => _("Environment"), :value => @record.configuration_profile.try(:configuration_environment_name)}
  end

  def textual_configuration_domain_name
    {:label => _("Domain"), :value => @record.configuration_profile.try(:configuration_domain_name)}
  end

  def textual_configuration_realm_name
    {:label => _("Realm"), :value => @record.configuration_profile.try(:configuration_realm_name)}
  end

  def textual_group_os
    [textual_configuration_compute_profile_name,
     textual_configuration_architecture_name,
     textual_operating_system_flavor_name,
     textual_customization_script_medium_name,
     textual_customization_script_ptable_name].flatten.compact
  end

  def textual_configuration_compute_profile_name
    {:label => _("Compute Profile"), :value => @record.configuration_profile.try(:configuration_compute_profile_name)}
  end

  def textual_configuration_architecture_name
    {:label => _("Architecture"), :value => @record.configuration_profile.try(:configuration_architecture_name)}
  end

  def textual_operating_system_flavor_name
    {:label => _("OS Information"), :value => @record.configuration_profile.try(:operating_system_flavor_name)}
  end

  def textual_customization_script_medium_name
    {:label => _("Medium"), :value => @record.configuration_profile.try(:customization_script_medium_name)}
  end

  def textual_customization_script_ptable_name
    {:label => _("Partition Table"), :value => @record.configuration_profile.try(:customization_script_ptable_name)}
  end

  def textual_group_tenancy
    [textual_configuration_locations_name,
     textual_configuration_organizations_name].flatten.compact
  end

  def textual_configuration_locations_name
    {:label => _("Configuration Location"),
     :value => (@record.configuration_profile.try(:configuration_locations) || []).collect(&:name).join(", ")
    }
  end

  def textual_configuration_organizations_name
    {:label => _("Configuration Organization"),
     :value => (@record.configuration_profile.try(:configuration_organizations) || []).collect(&:name).join(", ")
    }
  end

  def textual_configuration_profile_group_properties
    [textual_configuration_profile_name,
     textual_configuration_profile_region,
     textual_configuration_profile_zone].flatten.compact
  end

  def textual_configuration_profile_name
    {:label => "Name", :value => @record.name}
  end

  def textual_configuration_profile_region
    {:label => "Region", :value => @record.region_description}
  end

  def textual_configuration_profile_zone
    {:label => "Zone", :value => @record.my_zone}
  end

  def textual_configuration_profile_group_environment
    [textual_configuration_profile_environment,
     textual_configuration_profile_domain,
     textual_configuration_profile_puppet_realm].flatten.compact
  end

  def textual_configuration_profile_environment
    {:label => "Environment", :value => @record.configuration_environment_name}
  end

  def textual_configuration_profile_domain
    {:label => "Domain", :value => @record.configuration_domain_name}
  end

  def textual_configuration_profile_puppet_realm
    {:label => "Puppet Realm", :value => @record.configuration_realm_name}
  end

  def textual_configuration_profile_group_os
    [textual_configuration_profile_compute_profile,
     textual_configuration_profile_architecture,
     textual_configuration_profile_os,
     textual_configuration_profile_medium,
     textual_configuration_profile_partition_table].flatten.compact
  end

  def textual_configuration_profile_compute_profile
    {:label => _("Compute Profile"), :value => @record.configuration_compute_profile_name}
  end

  def textual_configuration_profile_architecture
    {:label => _("Architecture"), :value => @record.configuration_architecture_name}
  end

  def textual_configuration_profile_os
    {:label => _("OS"), :value => @record.operating_system_flavor_name}
  end

  def textual_configuration_profile_medium
    {:label => _("Medium"), :value => @record.customization_script_medium_name}
  end

  def textual_configuration_profile_partition_table
    {:label => _("Partition Table"), :value => @record.customization_script_ptable_name}
  end

  def textual_configuration_profile_group_tenancy
    [textual_configuration_profile_configuration_locations,
     textual_configuration_profile_configuration_organizations].flatten.compact
  end

  def textual_configuration_profile_configuration_locations
    {:label => _("Configuration Location"),
     :value => @record.configuration_locations.collect(&:name).join(", ")
    }
  end

  def textual_configuration_profile_configuration_organizations
    {:label => _("Configuration Organization"),
     :value => @record.configuration_organizations.collect(&:name).join(", ")
    }
  end
end
