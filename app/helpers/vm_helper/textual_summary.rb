module VmHelper::TextualSummary
  include TextualMixins::TextualAdvancedSettings
  include TextualMixins::TextualDescription
  include TextualMixins::TextualDrift
  include TextualMixins::TextualFilesystems
  include TextualMixins::TextualGroupTags
  include TextualMixins::TextualInitProcesses
  include TextualMixins::TextualName
  include TextualMixins::TextualOsInfo
  include TextualMixins::TextualPatches
  include TextualMixins::TextualPowerState
  include TextualMixins::TextualRegion
  include TextualMixins::TextualScanHistory
  # TODO: Determine if DoNav + url_for + :title is the right way to do links, or should it be link_to with :title

  #
  # Groups
  #

  def textual_group_properties
    %i(name region server description hostname ipaddress custom_1 container host_platform tools_status load_balancer_health_check_state osinfo devices cpu_affinity snapshots advanced_settings resources guid storage_profile)
  end

  def textual_group_lifecycle
    %i(discovered analyzed retirement_date retirement_state provisioned owner group)
  end

  def textual_group_relationships
    %i(ems cluster host resource_pool storage service parent_vm genealogy drift scan_history cloud_network cloud_subnet)
  end

  def textual_group_vm_cloud_relationships
    %i(ems ems_infra cluster host availability_zone cloud_tenant flavor vm_template drift scan_history service
       cloud_network cloud_subnet orchestration_stack cloud_networks cloud_subnets network_routers security_groups
       floating_ips network_ports load_balancers cloud_volumes)
  end

  def textual_group_template_cloud_relationships
    %i(ems parent_vm drift scan_history cloud_tenant)
  end

  def textual_group_security
    %i(users groups patches)
  end

  def textual_group_configuration
    %i(guest_applications init_processes win32_services kernel_drivers filesystem_drivers filesystems registry_items)
  end

  def textual_group_datastore_allocation
    %i(disks disks_aligned thin_provisioned allocated_disks allocated_total)
  end

  def textual_group_datastore_usage
    %i(usage_disks usage_snapshots usage_disk_storage usage_overcommitted)
  end

  def textual_group_diagnostics
    %i(processes event_logs)
  end

  def textual_group_storage_relationships
    %i(storage_systems storage_volumes logical_disks file_shares)
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

  def textual_group_power_management
    %i(power_state boot_time state_changed_on)
  end

  def textual_group_normal_operating_ranges
    %i(normal_operating_ranges_cpu normal_operating_ranges_cpu_usage normal_operating_ranges_memory normal_operating_ranges_memory_usage)
  end

  #
  # Items
  #
  def textual_server
    @record.miq_server && "#{@record.miq_server.name} [#{@record.miq_server.id}]"
  end

  def textual_hostname
    hostnames = @record.hostnames
    {:label => n_("Hostname", "Hostnames", hostnames.size), :value => hostnames.join(", ")}
  end

  def textual_ipaddress
    ips = @record.ipaddresses
    h = {:label    => n_("IP Address", "IP Addresses", ips.size),
         :value    => ips.join(", "),
         :explorer => true}
    if @record.hardware.try(:networks) && @record.hardware.networks.present?
      h[:link] = url_for(:action => 'show', :id => @record, :display => 'networks')
    end
    h
  end

  def textual_load_balancer_health_check_state
    return nil if @record.try(:load_balancer_health_check_states).blank?
    h = {:label    => _("Load Balancer Status"),
         :value    => @record.load_balancer_health_check_state,
         :title    => @record.load_balancer_health_check_states_with_reason.join("\n"),
         :explorer => true}
    h
  end

  def textual_custom_1
    return nil if @record.custom_1.blank?
    {:label => _("Custom Identifier"), :value => @record.custom_1}
  end

  def textual_container
    h = {:label => _("Container")}
    vendor = @record.vendor
    if vendor.blank?
      h[:value] = _("None")
    else
      h[:image] = "svg/vendor-#{vendor}.svg"
      h[:title] = _("Show VMM container information")
      h[:explorer] = true
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'hv_info')

      cpu_details =
        if @record.num_cpu && @record.cpu_cores_per_socket
          " (#{pluralize(@record.num_cpu, 'socket')} x #{pluralize(@record.cpu_cores_per_socket, 'core')})"
        else
          ""
        end
      h[:value] = "#{vendor}: #{pluralize(@record.cpu_total_cores, 'CPU')}#{cpu_details}, #{@record.mem_cpu} MB"
    end
    h
  end

  def textual_host_platform
    {:label => _("Parent %{title} Platform") % {:title => title_for_host},
     :value => (@record.host.nil? ? _("N/A") : @record.v_host_vmm_product)}
  end

  def textual_tools_status
    {:label => _("Platform Tools"), :value => (@record.tools_status.nil? ? _("N/A") : @record.tools_status)}
  end

  def textual_cpu_affinity
    {:label => _("CPU Affinity"), :value => @record.cpu_affinity}
  end

  def textual_snapshots
    num = @record.number_of(:snapshots)
    h = {:label => _("Snapshots"), :icon => "fa fa-camera", :value => (num == 0 ? _("None") : num)}
    if role_allows?(:feature => "vm_snapshot_show_list") && @record.supports_snapshots?
      h[:title] = _("Show the snapshot info for this VM")
      h[:explorer] = true
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'snapshot_info')
    end
    h
  end

  def textual_resources
    {:label => _("Resources"), :value => _("Available"), :title => _("Show resources of this VM"), :explorer => true,
      :link => url_for(:action => 'show', :id => @record, :display => 'resources_info')}
  end

  def textual_guid
    {:label => _("Management Engine GUID"), :value => @record.guid}
  end

  def textual_storage_profile
    return nil if @record.storage_profile.nil?
    {:label => _("Storage Profile"), :value => @record.storage_profile.name}
  end

  def textual_discovered
    {:label => _("Discovered"), :icon => "fa fa-search", :value => format_timezone(@record.created_on)}
  end

  def textual_analyzed
    {:label => _("Last Analyzed"),
     :icon  => "fa fa-search",
     :value => (@record.last_sync_on.nil? ? _("Never") : format_timezone(@record.last_sync_on))}
  end

  def textual_retirement_date
    return nil if @record.kind_of?(ManageIQ::Providers::Openstack::CloudManager::Template)
    {:label => _("Retirement Date"),
     :icon  => "fa fa-clock-o",
     :value => (@record.retires_on.nil? ? _("Never") : @record.retires_on.strftime("%x %R %Z"))}
  end

  def textual_retirement_state
    @record.retirement_state.to_s.capitalize
  end

  def textual_provisioned
    req = @record.miq_provision.nil? ? nil : @record.miq_provision.miq_request
    return nil if req.nil?
    {:label => _("Provisioned On"), :value => req.fulfilled_on.nil? ? "" : format_timezone(req.fulfilled_on)}
  end

  def textual_owner
    @record.evm_owner.try(:name)
  end

  def textual_group
    {:label => _("Group"), :value => @record.miq_group.try(:description)}
  end

  def textual_cluster
    cluster = @record.try(:ems_cluster)
    return nil if cluster.nil?
    h = {:label => title_for_cluster, :icon => "pficon pficon-cluster", :value => (cluster.nil? ? _("None") : cluster.name)}
    if cluster && role_allows?(:feature => "ems_cluster_show")
      h[:title] = _("Show this VM's %{title}") % {:title => title_for_cluster}
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'show', :id => cluster)
    end
    h
  end

  def textual_host
    host = @record.host
    return nil if host.nil?
    h = {:label => title_for_host, :icon => "pficon pficon-cluster", :value => (host.nil? ? _("None") : host.name)}
    if host && role_allows?(:feature => "host_show")
      h[:title] = _("Show this VM's %{title}") % {:title => title_for_host}
      h[:link]  = url_for(:controller => 'host', :action => 'show', :id => host)
    end
    h
  end

  def textual_resource_pool
    rp = @record.parent_resource_pool
    h = {:label => _("Resource Pool"), :icon => "pficon pficon-resource-pool", :value => (rp.nil? ? _("None") : rp.name)}
    if rp && role_allows?(:feature => "resource_pool_show")
      h[:title] = _("Show this VM's Resource Pool")
      h[:link]  = url_for(:controller => 'resource_pool', :action => 'show', :id => rp)
    end
    h
  end

  def textual_storage
    storages = @record.storages
    label = ui_lookup(:table => "storages")
    h = {:label => label, :icon => "fa fa-database"}
    if storages.empty?
      h[:value] = _("None")
    elsif storages.length == 1
      storage = storages.first
      h[:value] = storage.name
      h[:title] = _("Show this VM's %{label}") % {:label => label}
      h[:link]  = url_for(:controller => 'storage', :action => 'show', :id => storage)
    else
      h.delete(:image) # Image will be part of each line item, instead
      main = @record.storage
      h[:value] = storages.sort_by { |s| s.name.downcase }.collect do |s|
        {:icon  => "fa fa-database",
         :value => "#{s.name}#{" (main)" if s == main}",
         :title => _("Show this VM's %{label}") % {:label => label},
         :link  => url_for(:controller => 'storage', :action => 'show', :id => s)}
      end
    end
    h
  end

  def textual_ems
    textual_link(@record.ext_management_system)
  end

  def textual_ems_infra
    textual_link(@record.ext_management_system.try(:provider).try(:infra_ems))
  end

  def textual_availability_zone
    availability_zone = @record.availability_zone
    label = ui_lookup(:table => "availability_zone")
    h = {:label => label,
         :icon  => "pficon pficon-zone",
         :value => (availability_zone.nil? ? _("None") : availability_zone.name)}
    if availability_zone && role_allows?(:feature => "availability_zone_show")
      h[:title] = _("Show this VM's %{label}") % {:label => label}
      h[:link]  = url_for(:controller => 'availability_zone', :action => 'show', :id => availability_zone)
    end
    h
  end

  def textual_flavor
    flavor = @record.flavor
    label = ui_lookup(:table => "flavor")
    h = {:label => label, :icon => "pficon-flavor", :value => (flavor.nil? ? _("None") : flavor.name)}
    if flavor && role_allows?(:feature => "flavor_show")
      h[:title] = _("Show this VM's %{label}") % {:label => label}
      h[:link]  = url_for(:controller => 'flavor', :action => 'show', :id => flavor)
    end
    h
  end

  def textual_vm_template
    vm_template = @record.genealogy_parent
    label = ui_lookup(:table => "miq_template")
    h = {:label => label, :icon => "product product-template", :value => (vm_template.nil? ? _("None") : vm_template.name)}
    if vm_template && role_allows?(:feature => "miq_template_show")
      h[:title] = _("Show this VM's %{label}") % {:label => label}
      h[:link]  = url_for(:controller => 'miq_template', :action => 'show', :id => vm_template)
    end
    h
  end

  def textual_parent_vm
    return nil unless @record.template?
    h = {:label => _("Parent VM"), :icon => "pficon pficon-virtual-machine"}
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
    h = {:label => label, :icon => "product-orchestration_stack", :value => (stack.nil? ? _("None") : stack.name)}
    if stack && role_allows?(:feature => "orchestration_stack_show")
      h[:title] = _("Show this VM's %{label} '%{name}'") % {:label => label, :name => stack.name}
      h[:link]  = url_for(:controller => 'orchestration_stack', :action => 'show', :id => stack)
    end
    h
  end

  def textual_service
    h = {:label => _("Service"), :icon => "pficon pficon-service"}
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

  def textual_security_groups
    label = ui_lookup(:tables => "security_group")
    num   = @record.number_of(:security_groups)
    h     = {:label => label, :icon => "pficon pficon-cloud-security", :value => num}
    if num > 0 && role_allows?(:feature => "security_group_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:explorer] = true
      h[:link]  = url_for(:action => 'security_groups', :id => @record, :display => "security_groups")
    end
    h
  end

  def textual_floating_ips
    label = ui_lookup(:tables => "floating_ip")
    num   = @record.number_of(:floating_ips)
    h     = {:label => label, :icon => "fa fa-map-marker", :value => num}
    if num > 0 && role_allows?(:feature => "floating_ip_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:explorer] = true
      h[:link]  = url_for(:action => 'floating_ips', :id => @record, :display => "floating_ips")
    end
    h
  end

  def textual_network_routers
    label = ui_lookup(:tables => "network_router")
    num   = @record.number_of(:network_routers)
    h     = {:label => label, :icon => "pficon pficon-route", :value => num}
    if num > 0 && role_allows?(:feature => "network_router_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:explorer] = true
      h[:link]  = url_for(:action => 'network_routers', :id => @record, :display => "network_routers")
    end
    h
  end

  def textual_cloud_subnets
    label = ui_lookup(:tables => "cloud_subnet")
    num   = @record.number_of(:cloud_subnets)
    h     = {:label => label, :icon => "pficon pficon-network", :value => num}
    if num > 0 && role_allows?(:feature => "cloud_subnet_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:explorer] = true
      h[:link]  = url_for(:action => 'cloud_subnets', :id => @record, :display => "cloud_subnets")
    end
    h
  end

  def textual_network_ports
    label = ui_lookup(:tables => "network_port")
    num   = @record.number_of(:network_ports)
    h     = {:label => label, :icon => "product product-network_port", :value => num}
    if num > 0 && role_allows?(:feature => "network_port_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:explorer] = true
      h[:link]  = url_for(:action => 'network_ports', :id => @record, :display => "network_ports")
    end
    h
  end

  def textual_load_balancers
    return nil if @record.try(:load_balancers).nil?

    label = ui_lookup(:tables => "load_balancer")
    num   = @record.number_of(:load_balancers)
    h     = {:label => label, :icon => "product product-load_balancer", :value => num}
    if num > 0 && role_allows?(:feature => "load_balancer_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:explorer] = true
      h[:link]  = url_for(:action => 'load_balancers', :id => @record, :display => "load_balancers")
    end
    h
  end

  def textual_cloud_networks
    label = ui_lookup(:tables => "cloud_network")
    num   = @record.number_of(:cloud_networks)
    h     = {:label => label, :icon => "product product-cloud_network", :value => num}
    if num > 0 && role_allows?(:feature => "cloud_network_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:explorer] = true
      h[:link]  = url_for(:action => 'cloud_networks', :id => @record, :display => "cloud_networks")
    end
    h
  end

  def textual_cloud_tenant
    cloud_tenant = @record.cloud_tenant if @record.respond_to?(:cloud_tenant)
    label = ui_lookup(:table => "cloud_tenants")
    h = {:label => label, :icon => "pficon pficon-cloud-tenant", :value => (cloud_tenant.nil? ? _("None") : cloud_tenant.name)}
    if cloud_tenant && role_allows?(:feature => "cloud_tenant_show")
      h[:title] = _("Show this VM's %{label}") % {:label => label}
      h[:link]  = url_for(:controller => 'cloud_tenant', :action => 'show', :id => cloud_tenant)
    end
    h
  end

  def textual_cloud_volumes
    label = ui_lookup(:tables => "cloud_volumes")
    num = @record.number_of(:cloud_volumes)
    h = {:label => label, :icon => "pficon pficon-volume", :value => num}
    if num > 0 && role_allows?(:feature => "cloud_volume_show_list")
      h[:title]    = _("Show all Cloud Volumes attached to this VM.")
      h[:explorer] = true
      h[:link]     = url_for(:action => 'cloud_volumes', :id => @record, :display => "cloud_volumes")
    end
    h
  end

  def textual_genealogy
    {
      :label    => _("Genealogy"),
      :icon     => "product product-genealogy",
      :value    => _("Show parent and child VMs"),
      :title    => _("Show virtual machine genealogy"),
      :explorer => true,
      :spinner  => true,
      :link     => url_for(
        :controller => controller.controller_name,
        :action     => 'show',
        :id         => @record,
        :display    => "vmtree_info"
      )
    }
  end

  def textual_users
    num = @record.number_of(:users)
    h = {:label => _("Users"), :icon => "pficon pficon-user", :value => num}
    if num > 0
      h[:title] = n_("Show the User defined on this VM", "Show the Users defined on this VM", num)
      h[:explorer] = true
      h[:link]  = url_for(:action => 'users', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_groups
    num = @record.number_of(:groups)
    h = {:label => _("Groups"), :icon => "product product-group", :value => num}
    if num > 0
      h[:title] = n_("Show the Group defined on this VM", "Show the Groups defined on this VM", num)
      h[:explorer] = true
      h[:link]  = url_for(:action => 'groups', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_guest_applications
    os = @record.os_image_name.downcase
    return nil if os == "unknown"
    num = @record.number_of(:guest_applications)
    label = (os =~ /linux/) ? n_("Package", "Packages", num) : n_("Application", "Applications", num)

    h = {:label => label, :icon => "product product-application", :value => num}
    if num > 0
      h[:title] = _("Show the %{label} installed on this VM") % {:label => label}
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'guest_applications', :id => @record)
    end
    h
  end

  def textual_win32_services
    os = @record.os_image_name.downcase
    return nil if os == "unknown" || os =~ /linux/
    num = @record.number_of(:win32_services)
    h = {:label => _("Win32 Services"), :icon0 => "fa fa-cog", :value => num}
    if num > 0
      h[:title] = n_("Show the Win32 Service installed on this VM", "Show the Win32 Services installed on this VM", num)
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
    h = {:label => _("Kernel Drivers"), :icon => "fa fa-cog", :value => num}
    if num > 0
      h[:title] = n_("Show the Kernel Driver installed on this VM", "Show the Kernel Drivers installed on this VM", num)
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
    h = {:label => _("File System Drivers"), :icon => "fa fa-cog", :value => num}
    if num > 0
      h[:title] = n_("Show the File System Driver installed on this VM",
                     "Show the File System Drivers installed on this VM", num)
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'filesystem_drivers', :id => @record)
    end
    h
  end

  def textual_registry_items
    os = @record.os_image_name.downcase
    return nil if os == "unknown" || os =~ /linux/
    num = @record.number_of(:registry_items)
    # TODO: Why is this label different from the link title text?
    h = {:label => _("Registry Entries"), :icon => "pficon pficon-registry", :value => num}
    if num > 0
      h[:title] = n_("Show the Registry Item installed on this VM", "Show the Registry Items installed on this VM", num)
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'registry_items', :id => @record)
    end
    h
  end

  def textual_disks
    num = @record.hardware.nil? ? 0 : @record.hardware.number_of(:disks)
    h = {:label => _("Number of Disks"), :icon => "fa fa-hdd-o", :value => num}
    if num > 0
      h[:title] = n_("Show disk on this VM", "Show disks on this VM", num)
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => "disks")
    end
    h
  end

  def textual_disks_aligned
    {:label => _("Disks Aligned"), :value => @record.disks_aligned}
  end

  def textual_thin_provisioned
    {:label => _("Thin Provisioning Used"), :value => @record.thin_provisioned.to_s.capitalize}
  end

  def textual_allocated_disks
    h = {:label => _("Disks")}
    value = @record.allocated_disk_storage
    h[:title] = value.nil? ? _("N/A") : "#{number_with_delimiter(value)} bytes"
    h[:value] = value.nil? ? _("N/A") : number_to_human_size(value, :precision => 2)
    h
  end

  def textual_allocated_memory
    h = {:label => _("Memory")}
    value = @record.ram_size_in_bytes_by_state
    h[:title] = value.nil? ? _("N/A") : "#{number_with_delimiter(value)} bytes"
    h[:value] = value.nil? ? _("N/A") : number_to_human_size(value, :precision => 2)
    h
  end

  def textual_allocated_total
    h = textual_allocated_disks
    h[:label] = _("Total Allocation")
    h
  end

  def textual_usage_disks
    textual_allocated_disks
  end

  def textual_usage_memory
    textual_allocated_memory
  end

  def textual_usage_snapshots
    h = {:label => _("Snapshots")}
    value = @record.snapshot_storage
    h[:title] = value.nil? ? _("N/A") : "#{number_with_delimiter(value)} bytes"
    h[:value] = value.nil? ? _("N/A") : number_to_human_size(value, :precision => 2)
    h
  end

  def textual_usage_disk_storage
    h = {:label => _("Total Datastore Used Space")}
    value = @record.used_disk_storage
    h[:title] = value.nil? ? _("N/A") : "#{number_with_delimiter(value)} bytes"
    h[:value] = value.nil? ? _("N/A") : number_to_human_size(value, :precision => 2)
    h
  end

  def textual_usage_overcommitted
    h = {:label => _("Unused/Overcommited Allocation")}
    value = @record.uncommitted_storage
    h[:title] = value.nil? ? _("N/A") : "#{number_with_delimiter(value)} bytes"
    h[:value] = if value.nil?
                  _("N/A")
                else
                  v = number_to_human_size(value.abs, :precision => 2)
                  v = _("(%{value}) * Overallocated") % {:value => v} if value < 0
                  v
                end
    h
  end

  def textual_processes
    h = {:label => _("Running Processes"), :icon => "fa fa-cog"}
    date = last_date(:processes)
    if date.nil?
      h[:value] = _("Not Available")
    else
      # TODO: Why does this date differ in style from the compliance one?
      h[:value] = _("From %{time} Ago") % {:time => time_ago_in_words(date.in_time_zone(Time.zone)).titleize}
      h[:title] = _("Show Running Processes on this VM")
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'processes', :id => @record)
    end
    h
  end

  def textual_event_logs
    num = @record.operating_system.nil? ? 0 : @record.operating_system.number_of(:event_logs)
    h = {:label => _("Event Logs"), :icon => "fa fa-file-text-o", :value => (num == 0 ? _("Not Available") : _("Available"))}
    if num > 0
      h[:title] = _("Show Event Logs on this VM")
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'event_logs', :id => @record)
    end
    h
  end

  def textual_storage_systems
    num = @record.storage_systems_size
    label = ui_lookup(:tables => "ontap_storage_system")
    h = {:label => label, :icon => "pficon pficon-volume", :value => num}
    if num > 0 && role_allows?(:feature => "ontap_storage_system_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => "ontap_storage_systems")
    end
    h
  end

  def textual_storage_volumes
    num = @record.storage_volumes_size
    label = ui_lookup(:tables => "ontap_storage_volume")
    h = {:label => label, :icon => "pficon pficon-volume", :value => num}
    if num > 0 && role_allows?(:feature => "ontap_storage_volume_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => "ontap_storage_volumes")
    end
    h
  end

  def textual_file_shares
    num = @record.file_shares_size
    label = ui_lookup(:tables => "ontap_file_share")
    h = {:label => label, :icon => "product product-file_share", :value => num}
    if num > 0 && role_allows?(:feature => "ontap_file_share_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => "ontap_file_shares")
    end
    h
  end

  def textual_logical_disks
    num = @record.logical_disks_size
    label = ui_lookup(:tables => "ontap_logical_disk")
    h = {:label => label, :icon => "fa fa-hdd-o", :value => num}
    if num > 0 && role_allows?(:feature => "ontap_logical_disk_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => "ontap_logical_disks")
    end
    h
  end

  def textual_vmsafe_enable
    return nil if @record.vmsafe_enable
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
    super(:title    => _("Show Compliance History of this VM (Last 10 Checks)"),
          :explorer => true)
  end

  def textual_boot_time
    date = @record.boot_time
    {:label => _("Last Boot Time"), :value => (date.nil? ? _("N/A") : format_timezone(date))}
  end

  def textual_state_changed_on
    date = @record.state_changed_on
    {:label => _("State Changed On"), :value => (date.nil? ? _("N/A") : format_timezone(date))}
  end

  def textual_normal_operating_ranges_cpu
    h = {:label => _("CPU"), :value => []}
    [:max, _("Max"), :high, _("High"), :avg, _("Average"), :low, _("Low")].each_slice(2) do |key, label|
      value = @record.send("cpu_usagemhz_rate_average_#{key}_over_time_period")
      h[:value] << {:label => label, :value => (value.nil? ? _("Not Available") : mhz_to_human_size(value, 2))}
    end
    h
  end

  def textual_normal_operating_ranges_cpu_usage
    h = {:label => _("CPU Usage"), :value => []}
    [:max, _("Max"), :high, _("High"), :avg, _("Average"), :low, _("Low")].each_slice(2) do |key, label|
      value = @record.send("max_cpu_usage_rate_average_#{key}_over_time_period")
      h[:value] << {:label => label,
                    :value => (value.nil? ? _("Not Available") : number_to_percentage(value, :precision => 2))}
    end
    h
  end

  def textual_normal_operating_ranges_memory
    h = {:label => _("Memory"), :value => []}
    [:max, _("Max"), :high, _("High"), :avg, _("Average"), :low, _("Low")].each_slice(2) do |key, label|
      value = @record.send("derived_memory_used_#{key}_over_time_period")
      h[:value] << {:label => label,
                    :value => (value.nil? ? _("Not Available") : number_to_human_size(value.megabytes,
                                                                                      :precision => 2))}
    end
    h
  end

  def textual_normal_operating_ranges_memory_usage
    h = {:label => _("Memory Usage"), :value => []}
    [:max, _("Max"), :high, _("High"), :avg, _("Average"), :low, _("Low")].each_slice(2) do |key, label|
      value = @record.send("max_mem_usage_absolute_average_#{key}_over_time_period")
      h[:value] << {:label => label,
                    :value => (value.nil? ? _("Not Available") : number_to_percentage(value, :precision => 2))}
    end
    h
  end

  def textual_devices
    h = {:label    => _("Devices"),
         :icon     => "fa fa-hdd-o",
         :explorer => true,
         :value    => (@devices.nil? || @devices.empty? ? _("None") : @devices.length)}
    if @devices.length > 0
      h[:title] = _("Show VMs devices")
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'devices')
    end
    h
  end
end
