module HostHelper::TextualSummary
  # TODO: Determine if DoNav + url_for + :title is the right way to do links, or should it be link_to with :title

  #
  # Groups
  #

  def textual_group_properties
    %i(hostname ipaddress ipmi_ipaddress custom_1 vmm_vendor model asset_tag service_tag osinfo
       power_state lockdown_mode devices network storage_adapters num_cpu num_cpu_cores cores_per_socket memory
       guid)
  end

  def textual_group_relationships
    %i(ems cluster availability_zone used_tenants storages resource_pools vms miq_templates drift_history)
  end

  def textual_group_storage_relationships
    %i(storage_systems storage_volumes logical_disks file_shares)
  end

  def textual_group_compliance
    %i(compliance_status compliance_history)
  end

  def textual_group_security
    return nil if @record.is_vmware_esxi?
    %i(users groups patches firewall_rules ssh_root)
  end

  def textual_group_configuration
    %i(guest_applications host_services filesystems advanced_settings)
  end

  def textual_group_diagnostics
    return nil unless get_vmdb_config[:product][:proto]
    %i(esx_logs)
  end

  def textual_group_smart_management
    %i(tags)
  end

  def textual_group_miq_custom_attributes
    textual_miq_custom_attributes
  end

  def textual_group_ems_custom_attributes
    textual_ems_custom_attributes
  end

  def textual_group_authentications
    textual_authentications
  end

  def textual_group_openstack_status
    return nil unless @record.kind_of?(ManageIQ::Providers::Openstack::InfraManager::Host)
    textual_generate_openstack_status
  end

  #
  # Items
  #

  def textual_generate_openstack_status
    @record.host_service_group_openstacks.collect do |x|
      running_count       = x.running_system_services.count
      failed_count        = x.failed_system_services.count
      all_count           = x.system_services.count
      configuration_count = x.filesystems.count

      running = {:title => _("Show list of running %s") % (x.name), :value => _("Running (%s)") % running_count,
                 :image => failed_count == 0 && running_count > 0 ? 'status_complete' : nil,
                 :link => running_count > 0 ? url_for(:controller => controller.controller_name,
                                                      :action => 'host_services', :id => @record,
                                                      :db => controller.controller_name, :host_service_group => x.id,
                                                      :status => :running) : nil}

      failed = {:title => _("Show list of failed %s") % (x.name), :value => _("Failed (%s)") % failed_count,
                :image => failed_count > 0 ? 'status_error' : nil,
                :link => failed_count > 0 ? url_for(:controller => controller.controller_name,
                                                    :action => 'host_services', :id => @record,
                                                    :db => controller.controller_name, :host_service_group => x.id,
                                                    :status => :failed) : nil}

      all = {:title => _("Show list of all %s") % (x.name), :value => _("All (%s)") % all_count,
             :image => 'service',
             :link => all_count > 0 ? url_for(:controller => controller.controller_name, :action => 'host_services',
                                              :id => @record, :db => controller.controller_name,
                                              :host_service_group => x.id, :status => :all) : nil}

      configuration = {:title => _("Show list of configuration files of %s") % (x.name),
                       :image => 'filesystems',
                       :value => _("Configuration (%s)") % configuration_count,
                       :link  => configuration_count > 0 ? url_for(:controller => controller.controller_name,
                                                                  :action => 'filesystems', :id => @record,
                                                                  :db => controller.controller_name,
                                                                  :host_service_group => x.id) : nil}

      sub_items = [running, failed, all, configuration]

      {:value => x.name, :sub_items => sub_items}
    end
  end

  def textual_hostname
    @record.hostname
  end

  def textual_ipaddress
    @record.ipaddress
  end

  def textual_ipmi_ipaddress
    {:label => "IPMI IP Address", :value => "#{@record.ipmi_address}"}
  end

  def textual_custom_1
    return nil if @record.custom_1.blank?
    label = "Custom Identifier"
    h     = {:label => label, :value => @record.custom_1}
    h
  end

  def textual_vmm_vendor
    h = {:label => "VMM Information"}
    if @vmminfo.nil? || @vmminfo.empty?
      h[:value] = "None"
      h[:image] = "unknown"
    else
      h[:image] = "vendor-#{@vmminfo[0][:description].downcase}"
      h[:value] = @vmminfo[0][:description]
      h[:title] = "Show VMM container information"
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'hv_info')
    end
    h
  end

  def textual_model
    h = {:label => "Manufacturer / Model"}
    if !@record.hardware.nil? && (!@record.hardware.manufacturer.blank? || !@record.hardware.model.blank?)
      h[:value] = "#{@record.hardware.manufacturer} / #{@record.hardware.model}"
    else
      h[:value] = "N/A"
    end
    h
  end

  def textual_asset_tag
    @record.asset_tag
  end

  def textual_service_tag
    @record.service_tag
  end

  def textual_osinfo
    h = {:label => "Operating System"}
    if @osinfo.nil? || @osinfo.empty?
      h[:value] = "Unknown"
      h[:image] = "os-unknown"
    else
      h[:image] = "os-#{@record.os_image_name.downcase}"
      h[:value] = @osinfo[0][:description]
      unless @record.operating_system.version.blank?
        h[:value] << " #{@record.operating_system.version}"
      end
      unless @record.operating_system.build_number.blank?
        h[:value] << " Build #{@record.operating_system.build_number}"
      end

      h[:title] = "Show OS container information"
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'os_info')
    end
    h
  end

  def textual_power_state
    state = @record.state.to_s.downcase
    state = "unknown" if state.blank?
    {:label => "Power State", :image => "currentstate-#{state}", :value => state}
  end

  def textual_lockdown_mode
    {:label => "Lockdown Mode", :value => @record.admin_disabled ? "Enabled" : "Disabled"}
  end

  def textual_storage_adapters
    return nil if @record.openstack_host?
    num = @record.hardware.nil? ? 0 : @record.hardware.number_of(:storage_adapters)
    h = {:label => "Storage Adapters", :image => "sa", :value => num}
    if num > 0
      h[:title] = "Show #{host_title} Storage Adapters"
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'storage_adapters')
    end
    h
  end

  def textual_network
    return nil if @record.openstack_host?
    num = @record.number_of(:switches)
    h = {:label => "Network", :image => "network", :value => (num == 0 ? "N/A" : "Available")}
    if num > 0
      h[:title] = "Show #{host_title} Network"
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'network')
    end
    h
  end

  def textual_devices
    h = {:label => "Devices", :image => "devices", :value => (@devices.nil? || @devices.empty? ? "None" : @devices.length)}
    if @devices.length > 0
      h[:title] = "Show #{host_title} devices"
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'devices')
    end
    h
  end

  def textual_num_cpu
    {:label => "Number of CPUs", :value => @record.hardware.nil? ? "N/A" : @record.hardware.numvcpus}
  end

  def textual_num_cpu_cores
    {:label => "Number of CPU Cores", :value => @record.hardware.nil? ? "N/A" : @record.hardware.logical_cpus}
  end

  def textual_cores_per_socket
    {:label => "CPU Cores Per Socket", :value => @record.hardware.nil? ? "N/A" : @record.hardware.cores_per_socket}
  end

  def textual_memory
    {:label => "Memory", :value => (@record.hardware.nil? || !@record.hardware.memory_cpu.kind_of?(Numeric)) ? "N/A" : number_to_human_size(@record.hardware.memory_cpu.to_i * 1.megabyte, :precision => 0)}
  end

  def textual_guid
    {:label => "Management Engine GUID", :value => @record.guid}
  end

  def textual_ems
    textual_link(@record.ext_management_system)
  end

  def textual_cluster
    cluster = @record.ems_cluster
    h = {:label => title_for_cluster, :image => "ems_cluster", :value => (cluster.nil? ? "None" : cluster.name)}
    if cluster && role_allows(:feature => "ems_cluster_show")
      h[:title] = "Show this #{host_title}'s #{title_for_cluster}"
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'show', :id => cluster)
    end
    h
  end

  def textual_storages
    return nil if @record.openstack_host?
    textual_link(@record.storages)
  end

  def textual_resource_pools
    return nil if @record.openstack_host?
    textual_link(@record.resource_pools,
                 :as   => ResourcePool,
                 :link => url_for(:action => 'show', :id => @record, :display => 'resource_pools'))
  end

  def textual_drift_history
    return nil unless role_allows(:feature => "host_drift")
    label = "Drift History"
    num   = @record.number_of(:drift_states)
    h     = {:label => label, :image => "drift", :value => num}
    if num > 0
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:action => 'drift_history', :id => @record)
    end
    h
  end

  def textual_availability_zone
    return nil unless @record.openstack_host?
    availability_zone = @record.availability_zone
    label = ui_lookup(:table => "availability_zone")
    h = {:label => label, :image => "availability_zone", :value => (availability_zone.nil? ? "None" : availability_zone.name)}
    if availability_zone && role_allows(:feature => "availability_zone_show")
      h[:title] = _("Show this %s's %s") % [host_title, label]
      h[:link]  = url_for(:controller => 'availability_zone', :action => 'show', :id => availability_zone)
    end
    h
  end

  def textual_used_tenants
    return nil unless @record.openstack_host?
    textual_link(@record.cloud_tenants,
                 :as   => CloudTenant,
                 :link => url_for(:action => 'show', :id => @record, :display => 'cloud_tenants'))
  end

  def textual_vms
    @record.vms
  end

  def textual_miq_templates
    return nil if @record.openstack_host?
    @record.miq_templates
  end

  def textual_storage_systems
    num = @record.storage_systems_size
    label = ui_lookup(:tables => "ontap_storage_system")
    h = {:label => label, :image => "ontap_storage_system", :value => num}
    if num > 0 && role_allows(:feature => "ontap_storage_system_show_list")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => "ontap_storage_systems")
    end
    h
  end

  def textual_storage_volumes
    num = @record.storage_volumes_size
    label = ui_lookup(:tables => "ontap_storage_volume")
    h = {:label => label, :image => "ontap_storage_volume", :value => num}
    if num > 0 && role_allows(:feature => "ontap_storage_volume_show_list")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => "ontap_storage_volumes")
    end
    h
  end

  def textual_file_shares
    num = @record.file_shares_size
    label = ui_lookup(:tables => "ontap_file_share")
    h = {:label => label, :image => "ontap_file_share", :value => num}
    if num > 0 && role_allows(:feature => "ontap_file_share_show_list")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => "ontap_file_shares")
    end
    h
  end

  def textual_logical_disks
    num = @record.logical_disks_size
    label = ui_lookup(:tables => "ontap_logical_disk")
    h = {:label => label, :image => "ontap_logical_disk", :value => num}
    if num > 0 && role_allows(:feature => "ontap_logical_disk_show_list")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => "ontap_logical_disks")
    end
    h
  end

  def textual_compliance_status
    h = {:label => "Status"}
    if @record.number_of(:compliances) == 0
      h[:value] = "Never Verified"
    else
      compliant = @record.last_compliance_status
      date      = @record.last_compliance_timestamp
      h[:image] = compliant ? "check" : "x"
      h[:value] = "#{"Non-" unless compliant}Compliant as of #{time_ago_in_words(date.in_time_zone(Time.zone)).titleize} Ago"
      h[:title] = "Show Details of Compliance Check on #{format_timezone(date)}"
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => 'compliance_history', :count => 1)
    end
    h
  end

  def textual_compliance_history
    h = {:label => "History"}
    if @record.number_of(:compliances) == 0
      h[:value] = "Not Available"
    else
      h[:image] = "compliance"
      h[:value] = "Available"
      h[:title] = "Show Compliance History of this #{host_title} (Last 10 Checks)"
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => 'compliance_history')
    end
    h
  end

  def textual_users
    return nil if @record.is_vmware_esxi?
    num = @record.number_of(:users)
    h = {:label => "Users", :image => "user", :value => num}
    if num > 0
      h[:title] = "Show the #{pluralize(num, 'user')} defined on this VM"
      h[:link]  = url_for(:action => 'users', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_groups
    return nil if @record.is_vmware_esxi?
    num = @record.number_of(:groups)
    h = {:label => "Groups", :image => "group", :value => num}
    if num > 0
      h[:title] = "Show the #{pluralize(num, 'group')} defined on this #{host_title}"
      h[:link]  = url_for(:action => 'groups', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_firewall_rules
    return nil if @record.is_vmware_esxi?
    num = @record.number_of(:firewall_rules)
    h = {:label => "Firewall Rules", :image => "firewallrule", :value => num}
    if num > 0
      h[:title] = "Show the #{pluralize(num, 'Firewall Rule')} defined on this #{host_title}"
      h[:link]  = url_for(:action => 'firewall_rules', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_ssh_root
    return nil if @record.is_vmware_esxi?
    {:label => "SSH Root", :value => @record.ssh_permit_root_login}
  end

  def textual_patches
    return nil if @record.is_vmware_esxi?
    num = @record.number_of(:patches)
    h = {:label => "Patches", :image => "patch", :value => num}
    if num > 0
      h[:title] = "Show the #{pluralize(num, 'Patch')} defined on this #{host_title}"
      h[:link]  = url_for(:action => 'patches', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_guest_applications
    num = @record.number_of(:guest_applications)
    h = {:label => "Packages", :image => "guest_application", :value => num}
    if num > 0
      h[:title] = "Show the #{pluralize(num, "Package")} installed on this #{host_title}"
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'guest_applications', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_host_services
    num = @record.number_of(:host_services)
    h = {:label => "Services", :image => "service", :value => num}
    if num > 0
      h[:title] = "Show the #{pluralize(num, 'Service')} installed on this #{host_title}"
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'host_services', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_filesystems
    num = @record.number_of(:filesystems)
    h = {:label => "Files", :image => "filesystems", :value => num}
    if num > 0
      h[:title] = "Show the #{pluralize(num, 'File')} installed on this #{host_title}"
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'filesystems', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_advanced_settings
    num = @record.number_of(:advanced_settings)
    h = {:label => "Advanced Settings", :image => "advancedsetting", :value => num}
    if num > 0
      h[:title] = "Show the #{pluralize(num, 'Advanced Setting')} installed on this #{host_title}"
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'advanced_settings', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_esx_logs
    num = @record.operating_system.nil? ? 0 : @record.operating_system.number_of(:event_logs)
    h = {:label => "ESX Logs", :image => "logs", :value => (num == 0 ? "Not Available" : "Available")}
    if num > 0
      h[:title] = "Show #{host_title} Network"
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'event_logs')
    end
    h
  end

  def textual_miq_custom_attributes
    attrs = @record.miq_custom_attributes
    return nil if attrs.blank?
    attrs.collect { |a| {:label => a.name, :value => a.value} }
  end

  def textual_ems_custom_attributes
    attrs = @record.ems_custom_attributes
    return nil if attrs.blank?
    attrs.collect { |a| {:label => a.name, :value => a.value} }
  end

  def textual_authentications
    authentications = @record.authentication_userid_passwords + @record.authentication_key_pairs
    return [{:label => "Default Authentication", :title => "None", :value => "None"}] if authentications.blank?

    authentications.collect do |auth|
      label =
        case auth.authtype
        when "default" then "Default"
        when "ipmi" then "IPMI"
        when "remote" then  "Remote Login"
        when "ws" then "Web Services"
        when "ssh_keypair" then "SSH keypair"
        else;           "<Unknown>"
        end

      {:label => "#{label} Credentials", :value => auth.status || "None", :title => auth.status_details}
    end
  end

  def host_title
    title_for_host_record(@record)
  end
end
