module ProviderForemanHelper
  def textual_group_properties
    %i(hostname
       ipmi_present
       ipaddress
       mac_address
       configuration_profile_desc
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
    %i(tags)
  end

  def textual_group_environment
    %i(configuration_environment_name
       configuration_domain_name
       configuration_realm_name)
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
    %i(configuration_compute_profile_name
       configuration_architecture_name
       operating_system_flavor_name
       customization_script_medium_name
       customization_script_ptable_name)
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
    %i(configuration_locations_name
       configuration_organizations_name)
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
    %i(configuration_profile_name
       configuration_profile_region
       configuration_profile_zone)
  end

  def textual_configuration_profile_name
    {:label => _("Name"), :value => @record.name}
  end

  def textual_configuration_profile_region
    {:label => _("Region"), :value => @record.region_description}
  end

  def textual_configuration_profile_zone
    {:label => _("Zone"), :value => @record.my_zone}
  end

  def textual_configuration_profile_group_environment
    %i(configuration_profile_environment
       configuration_profile_domain
       configuration_profile_puppet_realm)
  end

  def textual_configuration_profile_environment
    {:label => _("Environment"), :value => @record.configuration_environment_name}
  end

  def textual_configuration_profile_domain
    {:label => _("Domain"), :value => @record.configuration_domain_name}
  end

  def textual_configuration_profile_puppet_realm
    {:label => _("Puppet Realm"), :value => @record.configuration_realm_name}
  end

  def textual_configuration_profile_group_os
    %i(configuration_profile_compute_profile
       configuration_profile_architecture
       configuration_profile_os
       configuration_profile_medium
       configuration_profile_partition_table)
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
    %i(configuration_profile_configuration_locations
       configuration_profile_configuration_organizations)
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

  def textual_inventory_group_properties
    %i(inventory_group_name
       inventory_group_region)
  end

  def textual_inventory_group_name
    {:label => _("Name"), :value => @record.name}
  end

  def textual_inventory_group_region
    {:label => _("Region"), :value => @record.region_description}
  end

  def textual_inventory_group_architecture
    {:label => _("Architecture"), :value => @record.configuration_architecture_name}
  end

  def textual__inventory_group_oos
    {:label => _("OS"), :value => @record.operating_system_flavor_name}
  end

  def textual_inventory_group_medium
    {:label => _("Medium"), :value => @record.customization_script_medium_name}
  end

  def textual_inventory_group_partition_table
    {:label => _("Partition Table"), :value => @record.customization_script_ptable_name}
  end
end
