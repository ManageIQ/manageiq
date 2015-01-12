module HostHelper::TextualSummary
  # TODO: Determine if DoNav + url_for + :title is the right way to do links, or should it be link_to with :title

  #
  # Groups
  #

  def textual_group_properties
    items = %w{hostname ipaddress ipmi_ipaddress custom_1 vmm_vendor model asset_tag service_tag osinfo power_state lockdown_mode devices
                network storage_adapters num_cpu num_cpu_cores cores_per_socket memory guid}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w{ems cluster storages resource_pools vms miq_templates drift_history}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_storage_relationships
    items = %w{storage_systems storage_volumes logical_disks file_shares}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_compliance
    items = %w{compliance_status compliance_history}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_security
    return nil if @record.is_vmware_esxi?
    items = %w{users groups patches firewall_rules ssh_root}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_configuration
    items = %w{guest_applications host_services filesystems advanced_settings}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_diagnostics
    return nil unless get_vmdb_config[:product][:proto]
    items = %w{esx_logs}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def textual_group_smart_management
    items = %w{tags}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_miq_custom_attributes
    items = %w{miq_custom_attributes}
    ret = items.collect { |m| self.send("textual_#{m}") }.flatten.compact
    return nil if ret.blank?
  end

  def textual_group_ems_custom_attributes
    items = %w{ems_custom_attributes}
    ret = items.collect { |m| self.send("textual_#{m}") }.flatten.compact
    return nil if ret.blank?
  end

  def textual_group_authentications
    items = %w{authentications}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_hostname
    {:label => "Hostname", :value => "#{@record.hostname}"}
  end

  def textual_ipaddress
    {:label => "IP Address", :value => "#{@record.ipaddress}"}
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
    if @vmminfo == nil || @vmminfo.empty?
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
    return nil if @record.asset_tag.blank?
    {:label => "Asset Tag", :value => @record.asset_tag}
  end

  def textual_service_tag
    return nil if @record.service_tag.blank?
    {:label => "Service Tag", :value => @record.service_tag}
  end

  def textual_osinfo
    h = {:label => "Operating System"}
    if @osinfo == nil || @osinfo.empty?
      h[:value] = "Unknown"
      h[:image] = "os-unknown"
    else
      h[:image] = "os-#{@record.os_image_name.downcase}"
      h[:value] = @osinfo[0][:description]
      if !@record.operating_system.version.blank?
        h[:value] << " #{@record.operating_system.version}"
      end
      if !@record.operating_system.build_number.blank?
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
    num = @record.hardware.nil? ? 0 : @record.hardware.number_of(:storage_adapters)
    h = {:label => "Storage Adapters", :image => "sa", :value => num}
    if num > 0
      h[:title] = "Show Host Storage Adapters"
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'storage_adapters')
    end
    h
  end

  def textual_network
    num = @record.number_of(:switches)
    h = {:label => "Network", :image => "network", :value => (num == 0 ? "N/A" : "Available")}
    if num > 0
      h[:title] = "Show Host Network"
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'network')
    end
    h
  end

  def textual_devices
    h = {:label => "Devices", :image => "devices", :value => (@devices == nil || @devices.empty? ? "None" : @devices.length)}
    if @devices.length > 0
      h[:title] = "Show Host devices"
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
    {:label => "Memory", :value => (@record.hardware.nil? || !@record.hardware.memory_cpu.kind_of?(Numeric)) ? "N/A" : number_to_human_size(@record.hardware.memory_cpu.to_i * 1.megabyte,:precision=>0)}
  end

  def textual_guid
    {:label => "Management Engine GUID", :value => @record.guid}
  end

  def textual_ems
    ems = @record.ext_management_system
    return nil if ems.nil?
    label = ui_lookup(:table => "ems_infra")
    h = {:label => label, :image => "vendor-#{ems.emstype.downcase}", :value => ems.name}
    if role_allows(:feature => "ems_infra_show")
      h[:title] = "Show parent #{label} '#{ems.name}'"
      h[:link]  = url_for(:controller => 'ems_infra', :action => 'show', :id => ems)
    end
    h
  end

  def textual_cluster
    cluster = @record.ems_cluster
    h = {:label => "Cluster", :image => "ems_cluster", :value => (cluster.nil? ? "None" : cluster.name)}
    if cluster && role_allows(:feature => "ems_cluster_show")
      h[:title] = "Show this Host's Cluster"
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'show', :id => cluster)
    end
    h
  end

  def textual_storages
    label = ui_lookup(:tables=>"storages")
    num   = @record.number_of(:storages)
    h     = {:label => label, :image => "storage", :value => num}
    if num > 0 && role_allows(:feature => "storage_show_list")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'storages')
    end
    h
  end

  def textual_resource_pools
    label = "Resource Pools"
    num   = @record.number_of(:resource_pools)
    h     = {:label => label, :image => "resource_pool", :value => num}
    if num > 0 && role_allows(:feature => "resource_pool_show_list")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'resource_pools')
    end
    h
  end

  def textual_drift_history
    return nil unless role_allows(:feature=>"host_drift")
    label = "Drift History"
    num   = @record.number_of(:drift_states)
    h     = {:label => label, :image => "drift", :value => num}
    if num > 0
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:action => 'drift_history', :id => @record)
    end
    h
  end

  def textual_vms
    label = "VMs"
    num   = @record.number_of(:vms)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'vms')
    end
    h
  end

  def textual_miq_templates
    label = ui_lookup(:tables=>"miq_template")
    num   = @record.number_of(:miq_templates)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "miq_template_show_list")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'miq_templates')
    end
    h
  end

  def textual_tags
    label = "#{session[:customer_name]} Tags"
    h     = {:label => label}
    tags  = session[:assigned_filters]
    if tags.empty?
      h[:image] = "smarttag"
      h[:value] = "No #{label} have been assigned"
    else
      h[:value] = tags.sort_by { |category, assigned| category.downcase }.collect { |category, assigned| {:image => "smarttag", :label => category, :value => assigned } }
    end
    h
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
      h[:title] = "Show Compliance History of this Host (Last 10 Checks)"
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
      h[:title] = "Show the #{pluralize(num, 'group')} defined on this Host"
      h[:link]  = url_for(:action => 'groups', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_firewall_rules
    return nil if @record.is_vmware_esxi?
    num = @record.number_of(:firewall_rules)
    h = {:label => "Firewall Rules", :image => "firewallrule", :value => num}
    if num > 0
      h[:title] = "Show the #{pluralize(num, 'Firewall Rule')} defined on this Host"
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
      h[:title] = "Show the #{pluralize(num, 'Patch')} defined on this Host"
      h[:link]  = url_for(:action => 'patches', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_guest_applications
    num = @record.number_of(:guest_applications)
    h = {:label => "Packages", :image => "guest_application", :value => num}
    if num > 0
      h[:title] = "Show the #{pluralize(num, "Package")} installed on this Host"
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'guest_applications', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_host_services
    num = @record.number_of(:host_services)
    h = {:label => "Services", :image => "service", :value => num}
    if num > 0
      h[:title] = "Show the #{pluralize(num, 'Service')} installed on this Host"
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'host_services', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_filesystems
    num = @record.number_of(:filesystems)
    h = {:label => "Files", :image => "filesystems", :value => num}
    if num > 0
      h[:title] = "Show the #{pluralize(num, 'File')} installed on this Host"
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'filesystems', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_advanced_settings
    num = @record.number_of(:advanced_settings)
    h = {:label => "Advanced Settings", :image => "advancedsetting", :value => num}
    if num > 0
      h[:title] = "Show the #{pluralize(num, 'Advanced Setting')} installed on this Host"
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'advanced_settings', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_esx_logs
    num = @record.operating_system.nil? ? 0 : @record.operating_system.number_of(:event_logs)
    h = {:label => "ESX Logs", :image => "logs", :value => (num == 0 ? "Not Available" : "Available")}
    if num > 0
      h[:title] = "Show Host Network"
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
    authentications = @record.authentication_userid_passwords
    return [{:label => "Default Authentication", :title => "None", :value => "None"}] if authentications.blank?

    authentications.collect do |auth|
      label =
        case auth.authtype
        when "default"; "Default"
        when "ipmi"; "IPMI"
        when "remote";  "Remote Login"
        when "ws"; "Web Services"
        else;           "<Unknown>"
        end

      {:label => "#{label} Credentials", :value => auth.status || "None", :title => auth.status_details}
    end
  end
end
