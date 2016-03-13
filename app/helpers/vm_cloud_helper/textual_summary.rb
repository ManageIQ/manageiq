module VmCloudHelper::TextualSummary
  # TODO: Determine if DoNav + url_for + :title is the right way to do links, or should it be link_to with :title

  #
  # Groups
  #

  def textual_group_properties
    %i(name region server description ipaddress custom_1 container tools_status osinfo architecture advanced_settings resources guid virtualization_type root_device_type)
  end

  def textual_group_vm_cloud_relationships
    %i(ems ems_infra cluster host availability_zone cloud_tenant flavor vm_template drift scan_history security_groups
       service cloud_network cloud_subnet orchestration_stack)
  end

  def textual_group_template_cloud_relationships
    %i(ems parent_vm drift scan_history)
  end

  def textual_group_security
    %i(users groups patches key_pairs)
  end

  def textual_group_configuration
    %i(guest_applications init_processes win32_services kernel_drivers filesystem_drivers filesystems registry_items)
  end

  def textual_group_diagnostics
    %i(processes event_logs)
  end

  def textual_group_vmsafe
    %i(vmsafe_enable vmsafe_agent_address vmsafe_agent_port vmsafe_fail_open vmsafe_immutable_vm vmsafe_timeout)
  end

  def textual_group_miq_custom_attributes
    textual_miq_custom_attributes
  end

  def textual_group_ems_custom_attributes
    textual_ems_custom_attributes
  end

  def textual_group_compliance
    %i(compliance_status compliance_history)
  end

  def textual_group_power_management
    %i(power_state boot_time state_changed_on)
  end

  def textual_group_tags
    %i(tags)
  end

  #
  # Items
  #

  def textual_region
    return nil if @record.region_number == MiqRegion.my_region_number
    h = {:label => _("Region")}
    reg = @record.miq_region
    url = reg.remote_ui_url
    h[:value] = if url
                  # TODO: Why is this link different than the others?
                  link_to(reg.description, url_for(:host   => url,
                                                   :action => 'show',
                                                   :id     => @record),
                          :title   => _("Connect to this VM in its Region"),
                          :onclick => "return miqClickAndPop(this);")
                else
                  reg.description
                end
    h
  end

  def textual_name
    @record.name
  end

  def textual_server
    @record.miq_server && "#{@record.miq_server.name} [#{@record.miq_server.id}]"
  end

  def textual_description
    @record.description
  end

  def textual_ipaddress
    return nil if @record.template?
    ips = @record.ipaddresses
    {:label => n_("IP Address", "IP Addresses", ips.size), :value => ips.join(", ")}
  end

  def textual_custom_1
    return nil if @record.custom_1.blank?
    {:label => _("Custom Identifier"), :value => @record.custom_1}
  end

  def textual_tools_status
    {:label => _("Platform Tools"), :value => (@record.tools_status.nil? ? _("N/A") : @record.tools_status)}
  end

  def textual_osinfo
    h = {:label => "Operating System"}
    os = @record.operating_system.nil? ? nil : @record.operating_system.product_name
    if os.blank?
      h[:value] = _("Unknown")
    else
      h[:image] = "os-#{@record.os_image_name.downcase}"
      h[:value] = os
      h[:title] = _("Show OS container information")
      h[:explorer] = true
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'os_info')
    end
    h
  end

  def textual_architecture
    return nil if @record.kind_of?(ManageIQ::Providers::Openstack::CloudManager::Vm)
    bitness = @record.hardware.try(:bitness)
    {:label => _("Architecture "), :value => bitness.nil? ? "" : "#{bitness} bit"}
  end

  def textual_advanced_settings
    num = @record.number_of(:advanced_settings)
    h = {:label => _("Advanced Settings"), :image => "advancedsetting", :value => num}
    if num > 0
      h[:title] = _("Show the advanced settings on this VM")
      h[:explorer] = true
      h[:link]  = url_for(:action => 'advanced_settings', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_resources
    return nil if @record.template?
    {:label => _("Resources"), :value => _("Available"), :title => _("Show resources of this VM"), :explorer => true,
      :link => url_for(:action => 'show', :id => @record, :display => 'resources_info')}
  end

  def textual_guid
    {:label => _("Management Engine GUID"), :value => @record.guid}
  end

  def textual_ems
    textual_link(@record.ext_management_system)
  end

  def textual_ems_infra
    textual_link(@record.ext_management_system.try(:provider).try(:infra_ems))
  end

  def textual_cluster
    cluster = @record.host.try(:ems_cluster)
    return nil if cluster.nil?
    h = {:label => title_for_cluster, :image => "ems_cluster", :value => (cluster.nil? ? _("None") : cluster.name)}
    if cluster && role_allows(:feature => "ems_cluster_show")
      h[:title] = _("Show this VM's %{title}") % {:title => title_for_cluster}
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'show', :id => cluster)
    end
    h
  end

  def textual_host
    host = @record.host
    return nil if host.nil?
    h = {:label => title_for_host, :image => "host", :value => (host.nil? ? _("None") : host.name)}
    if host && role_allows(:feature => "host_show")
      h[:title] = _("Show this VM's %{title}") % {:title => title_for_host}
      h[:link]  = url_for(:controller => 'host', :action => 'show', :id => host)
    end
    h
  end

  def textual_availability_zone
    availability_zone = @record.availability_zone
    label = ui_lookup(:table => "availability_zone")
    h = {:label => label,
         :image => "availability_zone",
         :value => (availability_zone.nil? ? _("None") : availability_zone.name)}
    if availability_zone && role_allows(:feature => "availability_zone_show")
      h[:title] = _("Show this VM's %{label}") % {:label => label}
      h[:link]  = url_for(:controller => 'availability_zone', :action => 'show', :id => availability_zone)
    end
    h
  end

  def textual_flavor
    flavor = @record.flavor
    label = ui_lookup(:table => "flavor")
    h = {:label => label, :image => "flavor", :value => (flavor.nil? ? _("None") : flavor.name)}
    if flavor && role_allows(:feature => "flavor_show")
      h[:title] = _("Show this VM's %{label}") % {:label => label}
      h[:link]  = url_for(:controller => 'flavor', :action => 'show', :id => flavor)
    end
    h
  end

  def textual_vm_template
    vm_template = @record.genealogy_parent
    label = ui_lookup(:table => "miq_template")
    h = {:label => label, :image => "template", :value => (vm_template.nil? ? _("None") : vm_template.name)}
    if vm_template && role_allows(:feature => "miq_template_show")
      h[:title] = _("Show this VM's %{label}") % {:label => label}
      h[:link]  = url_for(:controller => 'miq_template', :action => 'show', :id => vm_template)
    end
    h
  end

  def textual_parent_vm
    return nil unless @record.template?
    h = {:label => _("Parent VM"), :image => "vm"}
    parent_vm = @record.with_relationship_type("genealogy", &:parent)
    if parent_vm.nil?
      h[:value] = _("None")
    else
      h[:value] = parent_vm.name
      h[:title] = _("Show this Image's parent")
      h[:explorer] = true
      url, action = set_controller_action
      h[:link]  = url_for(:controller => url, :action => action, :id => parent_vm)
    end
    h
  end

  def textual_orchestration_stack
    stack = @record.orchestration_stack
    label = ui_lookup(:table => "orchestration_stack")
    h = {:label => label, :image => "orchestration_stack", :value => (stack.nil? ? _("None") : stack.name)}
    if stack && role_allows(:feature => "orchestration_stack_show")
      h[:title] = _("Show this VM's %{label} '%{name}'") % {:label => label, :name => stack.name}
      h[:link]  = url_for(:controller => 'orchestration_stack', :action => 'show', :id => stack)
    end
    h
  end

  def textual_service
    h = {:label => _("Service"), :image => "service"}
    service = @record.service
    if service.nil?
      h[:value] = _("None")
    else
      h[:value] = service.name
      h[:title] = _("Show this Service")
      h[:link]  = url_for(:controller => 'service', :action => 'show', :id => service)
    end
    h
  end

  def textual_drift
    return nil unless role_allows(:feature => "vm_drift")
    h = {:label => _("Drift History"), :image => "drift"}
    num = @record.number_of(:drift_states)
    if num == 0
      h[:value] = _("None")
    else
      h[:value] = num
      h[:title] = _("Show virtual machine drift history")
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'drift_history', :id => @record)
    end
    h
  end

  def textual_scan_history
    h = {:label => _("Analysis History"), :image => "scan"}
    num = @record.number_of(:scan_histories)
    if num == 0
      h[:value] = _("None")
    else
      h[:value] = num
      h[:title] = _("Show virtual machine analysis history")
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'scan_histories', :id => @record)
    end
    h
  end

  def textual_users
    num = @record.number_of(:users)
    h = {:label => _("Users"), :image => "user", :value => num}
    if num > 0
      h[:title] = n_("Show the User defined on this VM", "Show the Users defined on this VM", num)
      h[:explorer] = true
      h[:link]  = url_for(:action => 'users', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_groups
    num = @record.number_of(:groups)
    h = {:label => _("Groups"), :image => "group", :value => num}
    if num > 0
      h[:title] = n_("Show the Group defined on this VM", "Show the Groups defined on this VM", num)
      h[:explorer] = true
      h[:link]  = url_for(:action => 'groups', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_patches
    os = @record.os_image_name.downcase
    return nil if os == "unknown" || os =~ /linux/
    num = @record.number_of(:patches)
    h = {:label => _("Patches"), :image => "patch", :value => num}
    if num > 0
      h[:title] = n_("Show the Patch defined on this VM", "Show the Patches defined on this VM", num)
      h[:explorer] = true
      h[:link]  = url_for(:action => 'patches', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_key_pairs
    return nil if @record.kind_of?(ManageIQ::Providers::CloudManager::Template)
    h = {:label => _("Key Pairs")}
    key_pairs = @record.key_pairs
    h[:value] = key_pairs.blank? ? _("N/A") : key_pairs.collect(&:name).join(", ")
    h
  end

  def textual_guest_applications
    os = @record.os_image_name.downcase
    return nil if os == "unknown"
    num = @record.number_of(:guest_applications)
    label = (os =~ /linux/) ? n_("Package", "Packages", num) : n_("Application", "Applications", num)
    h = {:label => label, :image => "guest_application", :value => num}
    if num > 0
      h[:title] = ("Show the %{label} installed on this VM") % {:label => label}
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'guest_applications', :id => @record)
    end
    h
  end

  def textual_init_processes
    os = @record.os_image_name.downcase
    return nil unless os =~ /linux/
    num = @record.number_of(:linux_initprocesses)
    # TODO: Why is this image different than graphical?
    h = {:label => _("Init Processes"), :image => "gears", :value => num}
    if num > 0
      h[:title] = n_("Show the Init Process installed on this VM",
                     "Show the Init Processes installed on this VM", num)
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'linux_initprocesses', :id => @record)
    end
    h
  end

  def textual_win32_services
    os = @record.os_image_name.downcase
    return nil if os == "unknown" || os =~ /linux/
    num = @record.number_of(:win32_services)
    h = {:label => _("Win32 Services"), :image => "win32service", :value => num}
    if num > 0
      h[:title] = n_("Show the Win32 Service installed on this VM",
                     "Show the Win32 Services installed on this VM", num)
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'win32_services', :id => @record)
    end
    h
  end

  def textual_kernel_drivers
    os = @record.os_image_name.downcase
    return nil if os == "unknown" || os =~ /linux/
    num = @record.number_of(:kernel_drivers)
    # TODO: Why is this image different than graphical?
    h = {:label => _("Kernel Drivers"), :image => "gears", :value => num}
    if num > 0
      h[:title] = n_("Show the Kernel Driver installed on this VM",
                     "Show the Kernel Drivers installed on this VM", num)
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'kernel_drivers', :id => @record)
    end
    h
  end

  def textual_filesystem_drivers
    os = @record.os_image_name.downcase
    return nil if os == "unknown" || os =~ /linux/
    num = @record.number_of(:filesystem_drivers)
    # TODO: Why is this image different than graphical?
    h = {:label => _("File System Drivers"), :image => "gears", :value => num}
    if num > 0
      h[:title] = n_("Show the File System Driver installed on this VM" ,
                    "Show the File System Drivers installed on this VM", num)
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'filesystem_drivers', :id => @record)
    end
    h
  end

  def textual_filesystems
    num = @record.number_of(:filesystems)
    h = {:label => _("Files"), :image => "filesystems", :value => num}
    if num > 0
      h[:title] = n_("Show the File installed on this VM", "Show the Files installed on this VM", num)
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'filesystems', :id => @record)
    end
    h
  end

  def textual_registry_items
    os = @record.os_image_name.downcase
    return nil if os == "unknown" || os =~ /linux/
    num = @record.number_of(:registry_items)
    # TODO: Why is this label different from the link title text?
    h = {:label => _("Registry Entries"), :image => "registry_item", :value => num}
    if num > 0
      h[:title] = n_("Show the Registry Item installed on this VM", "Show the Registry Items installed on this VM", num)
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'registry_items', :id => @record)
    end
    h
  end

  def textual_processes
    return nil if @record.kind_of?(ManageIQ::Providers::Openstack::CloudManager::Template)
    h = {:label => _("Running Processes"), :image => "processes"}
    date = last_date(:processes)
    if date.nil?
      h[:value] = _("Not Available")
    else
      # TODO: Why does this date differ in style from the compliance one?
      h[:value] = _("From %{time} Ago") % {:time => time_ago_in_words(date.in_time_zone(Time.zone)).titleize}
      h[:title] = n_("Show Running Process on this VM", "Show Running Processes on this VM", num)
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'processes', :id => @record)
    end
    h
  end

  def textual_event_logs
    return nil if @record.kind_of?(ManageIQ::Providers::Openstack::CloudManager::Template)
    num = @record.operating_system.nil? ? 0 : @record.operating_system.number_of(:event_logs)
    h = {:label => _("Event Logs"), :image => "event_logs", :value => (num == 0 ? _("Not Available") : _("Available"))}
    if num > 0
      h[:title] = n_("Show Event Log on this VM", "Show Event Logs on this VM", num)
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'event_logs', :id => @record)
    end
    h
  end

  def textual_vmsafe_enable
    return nil if @record.vmsafe_enable || @record.kind_of?(ManageIQ::Providers::Openstack::CloudManager::Template)
    {:label => _("Enable"), :value => "false"}
  end

  def textual_vmsafe_agent_address
    return nil unless @record.vmsafe_enable
    {:label => _("Agent Address"), :value => @record.vmsafe_agent_address}
  end

  def textual_vmsafe_agent_port
    return nil unless @record.vmsafe_enable
    {:label => _("Agent Port"), :value => @record.vmsafe_agent_port}
  end

  def textual_vmsafe_fail_open
    return nil unless @record.vmsafe_enable
    {:label => _("Fail Open"), :value => @record.vmsafe_fail_open}
  end

  def textual_vmsafe_immutable_vm
    return nil unless @record.vmsafe_enable
    {:label => _("Immutable VM"), :value => @record.vmsafe_immutable_vm}
  end

  def textual_vmsafe_timeout
    return nil unless @record.vmsafe_enable
    {:label => _("Timeout (ms)"), :value => @record.vmsafe_timeout_ms}
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

  def textual_compliance_history
    h = {:label => _("History")}
    if @record.number_of(:compliances) == 0
      h[:value] = _("Not Available")
    else
      h[:image] = "compliance"
      h[:value] = _("Available")
      h[:title] = _("Show Compliance History of this VM (Last 10 Checks)")
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => 'compliance_history')
    end
    h
  end

  def textual_power_state
    state = @record.current_state.downcase
    state = "unknown" if state.blank?
    h = {:label => _("Power State"), :value => state}
    h[:image] = "currentstate-#{@record.template? ? (@record.host ? "template" : "template-no-host") : state}"
    h
  end

  def textual_boot_time
    return nil if @record.kind_of?(ManageIQ::Providers::Openstack::CloudManager::Template)
    date = @record.boot_time
    {:label => _("Last Boot Time"), :value => (date.nil? ? _("N/A") : format_timezone(date))}
  end

  def textual_state_changed_on
    return nil if @record.kind_of?(ManageIQ::Providers::Openstack::CloudManager::Template)
    date = @record.state_changed_on
    {:label => _("State Changed On"), :value => (date.nil? ? _("N/A") : format_timezone(date))}
  end

  def textual_security_groups
    label = ui_lookup(:tables => "security_group")
    num   = @record.number_of(:security_groups)
    h     = {:label => label, :image => "security_group", :value => num}
    if num > 0 && role_allows(:feature => "security_group_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:explorer] = true
      h[:link]  = url_for(:action => 'security_groups', :id => @record, :display => "security_groups")
    end
    h
  end

  def textual_virtualization_type
    return nil if @record.kind_of?(ManageIQ::Providers::Openstack::CloudManager::Vm)
    v_type = @record.hardware.try(:virtualization_type)
    {:label => _("Virtualization Type"), :value => v_type.to_s}
  end

  def textual_root_device_type
    return nil if @record.kind_of?(ManageIQ::Providers::Openstack::CloudManager::Vm)
    rd_type = @record.hardware.try(:root_device_type)
    {:label => _("Root Device Type"), :value => rd_type.to_s}
  end

  def textual_cloud_tenant
    cloud_tenant = @record.cloud_tenant if @record.respond_to?(:cloud_tenant)
    label = ui_lookup(:table => "cloud_tenants")
    h = {:label => label, :image => "cloud_tenant", :value => (cloud_tenant.nil? ? _("None") : cloud_tenant.name)}
    if cloud_tenant && role_allows(:feature => "cloud_tenant_show")
      h[:title] = _("Show this VM's %{label}") % {:label => label}
      h[:link]  = url_for(:controller => 'cloud_tenant', :action => 'show', :id => cloud_tenant)
    end
    h
  end
end
