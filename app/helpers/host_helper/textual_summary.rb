module HostHelper::TextualSummary
  # TODO: Determine if DoNav + url_for + :title is the right way to do links, or should it be link_to with :title

  #
  # Groups
  #

  def textual_group_properties
    %i(hostname ipaddress ipmi_ipaddress custom_1 vmm_vendor_display model asset_tag service_tag osinfo
       power_state lockdown_mode maintenance_mode devices network storage_adapters num_cpu num_cpu_cores
       cpu_cores_per_socket memory guid)
  end

  def textual_group_relationships
    %i(ems cluster availability_zone used_tenants storages resource_pools vms templates drift_history)
  end

  def textual_group_storage_relationships
    %i(storage_systems storage_volumes logical_disks file_shares)
  end

  def textual_group_security
    return nil if @record.is_vmware_esxi?
    %i(users groups patches firewall_rules ssh_root)
  end

  def textual_group_configuration
    %i(guest_applications host_services filesystems advanced_settings)
  end

  def textual_group_diagnostics
    return nil unless ::Settings.product.proto
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
    textual_authentications(@record.authentication_userid_passwords + @record.authentication_key_pairs)
  end

  def textual_group_cloud_services
    textual_openstack_nova_scheduler if @record.openstack_host?
  end

  def textual_group_openstack_service_status
    return nil unless @record.kind_of?(ManageIQ::Providers::Openstack::InfraManager::Host)
    textual_generate_openstack_status
  end

  def textual_group_openstack_hardware_status
    return nil unless @record.kind_of?(ManageIQ::Providers::Openstack::InfraManager::Host)
    %i(introspected provision_state)
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

      running = {:title => _("Show list of running %{name}") % {:name => x.name},
                 :value => _("Running (%{number})") % {:number => running_count},
                 :image => failed_count == 0 && running_count > 0 ? '100/status_complete.png' : nil,
                 :link => running_count > 0 ? url_for(:controller => controller.controller_name,
                                                      :action => 'host_services', :id => @record,
                                                      :db => controller.controller_name, :host_service_group => x.id,
                                                      :status => :running) : nil}

      failed = {:title => _("Show list of failed %{name}") % {:name => x.name},
                :value => _("Failed (%{number})") % {:number => failed_count},
                :image => failed_count > 0 ? '100/status_error.png' : nil,
                :link => failed_count > 0 ? url_for(:controller => controller.controller_name,
                                                    :action => 'host_services', :id => @record,
                                                    :db => controller.controller_name, :host_service_group => x.id,
                                                    :status => :failed) : nil}

      all = {:title => _("Show list of all %{name}") % {:name => x.name},
             :value => _("All (%{number})") % {:number => all_count},
             :image => '100/service.png',
             :link => all_count > 0 ? url_for(:controller => controller.controller_name, :action => 'host_services',
                                              :id => @record, :db => controller.controller_name,
                                              :host_service_group => x.id, :status => :all) : nil}

      configuration = {:title => _("Show list of configuration files of %{name}") % {:name => x.name},
                       :image => '100/filesystems.png',
                       :value => _("Configuration (%{number})") % {:number => configuration_count},
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
    {:label => _("IP Address"), :value => @record.ipaddress.to_s}
  end

  def textual_ipmi_ipaddress
    {:label => _("IPMI IP Address"), :value => @record.ipmi_address.to_s}
  end

  def textual_custom_1
    return nil if @record.custom_1.blank?
    label = _("Custom Identifier")
    h     = {:label => label, :value => @record.custom_1}
    h
  end

  def textual_vmm_vendor_display
    h = {:label => _("VMM Information")}
    if @vmminfo.nil? || @vmminfo.empty?
      h[:value] = _("None")
      h[:image] = "100/unknown.png"
    else
      h[:image] = "100/vendor-#{@vmminfo[0][:description].downcase}.png"
      h[:value] = @vmminfo[0][:description]
      h[:title] = _("Show VMM container information")
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'hv_info')
    end
    h
  end

  def textual_model
    h = {:label => _("Manufacturer / Model")}
    if !@record.hardware.nil? && (!@record.hardware.manufacturer.blank? || !@record.hardware.model.blank?)
      h[:value] = "#{@record.hardware.manufacturer} / #{@record.hardware.model}"
    else
      h[:value] = _("N/A")
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
    h = {:label => _("Operating System")}
    if @osinfo.nil? || @osinfo.empty?
      h[:value] = _("Unknown")
      h[:image] = "100/os-unknown.png"
    else
      h[:image] = "100/os-#{@record.os_image_name.downcase}.png"
      h[:value] = @osinfo[0][:description]
      unless @record.operating_system.version.blank?
        h[:value] << " #{@record.operating_system.version}"
      end
      unless @record.operating_system.build_number.blank?
        h[:value] << _(" Build %{number}") % {:number => @record.operating_system.build_number}
      end

      h[:title] = _("Show OS container information")
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'os_info')
    end
    h
  end

  def textual_power_state
    state = @record.state.to_s.downcase
    state = "unknown" if state.blank?
    {:label => _("Power State"), :image => "100/currentstate-#{state}.png", :value => state}
  end

  def textual_lockdown_mode
    {:label => _("Lockdown Mode"), :value => @record.admin_disabled ? _("Enabled") : _("Disabled")}
  end

  def textual_maintenance_mode
    {:label => _("Maintenance Mode"), :value => @record.maintenance ? _("Enabled") : _("Disabled")}
  end

  def textual_storage_adapters
    return nil if @record.openstack_host?
    num = @record.hardware.nil? ? 0 : @record.hardware.number_of(:storage_adapters)
    h = {:label => _("Storage Adapters"), :image => "100/sa.png", :value => num}
    if num > 0
      h[:title] = _("Show %{title} Storage Adapters") % {:title => host_title}
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'storage_adapters')
    end
    h
  end

  def textual_network
    return nil if @record.openstack_host?
    num = @record.number_of(:switches)
    h = {:label => _("Network"), :image => "100/network.png", :value => (num == 0 ? _("N/A") : _("Available"))}
    if num > 0
      h[:title] = _("Show %{title} Network") % {:title => host_title}
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'network')
    end
    h
  end

  def textual_devices
    h = {:label => _("Devices"),
         :image => "100/devices.png",
         :value => (@devices.nil? || @devices.empty? ? _("None") : @devices.length)}
    if @devices.length > 0
      h[:title] = _("Show %{title} devices") % {:title => host_title}
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'devices')
    end
    h
  end

  def textual_num_cpu
    {:label => _("Number of CPUs"), :value => @record.hardware.nil? ? _("N/A") : @record.hardware.cpu_sockets}
  end

  def textual_num_cpu_cores
    {:label => _("Number of CPU Cores"), :value => @record.hardware.nil? ? _("N/A") : @record.hardware.cpu_total_cores}
  end

  def textual_cpu_cores_per_socket
    {:label => _("CPU Cores Per Socket"),
     :value => @record.hardware.nil? ? _("N/A") : @record.hardware.cpu_cores_per_socket}
  end

  def textual_memory
    {:label => _("Memory"),
     :value => if @record.hardware.nil? || !@record.hardware.memory_mb.kind_of?(Numeric)
                 _("N/A")
               else
                 number_to_human_size(@record.hardware.memory_mb.to_i * 1.megabyte, :precision => 0)
               end}
  end

  def textual_guid
    {:label => _("Management Engine GUID"), :value => @record.guid}
  end

  def textual_ems
    textual_link(@record.ext_management_system)
  end

  def textual_cluster
    cluster = @record.ems_cluster
    h = {:label => title_for_cluster, :image => "100/ems_cluster.png", :value => (cluster.nil? ? _("None") : cluster.name)}
    if cluster && role_allows?(:feature => "ems_cluster_show")
      h[:title] = _("Show this %{host_title}'s %{cluster_title}") %
                  {:host_title => host_title, :cluster_title => title_for_cluster}
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
    return nil unless role_allows?(:feature => "host_drift")
    label = _("Drift History")
    num   = @record.number_of(:drift_states)
    h     = {:label => label, :image => "100/drift.png", :value => num}
    if num > 0
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:link]  = url_for(:action => 'drift_history', :id => @record)
    end
    h
  end

  def textual_availability_zone
    return nil unless @record.openstack_host?
    availability_zone = @record.availability_zone
    label = ui_lookup(:table => "availability_zone")
    h = {:label => label,
         :image => "100/availability_zone.png",
         :value => (availability_zone.nil? ? _("None") : availability_zone.name)}
    if availability_zone && role_allows?(:feature => "availability_zone_show")
      h[:title] = _("Show this %{title}'s %{label}") % {:title => host_title, :label => label}
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
    label = _("VMs")
    num   = @record.number_of(:vms)
    h     = {:label => label, :image => "100/vm.png", :value => num}
    if num > 0 && role_allows?(:feature => "vm_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'vms')
    end
    h
  end

  def textual_templates
    return nil if @record.openstack_host?
    @record.miq_templates
  end

  def textual_storage_systems
    num = @record.storage_systems_size
    label = ui_lookup(:tables => "ontap_storage_system")
    h = {:label => label, :image => "100/ontap_storage_system.png", :value => num}
    if num > 0 && role_allows?(:feature => "ontap_storage_system_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => "ontap_storage_systems")
    end
    h
  end

  def textual_storage_volumes
    num = @record.storage_volumes_size
    label = ui_lookup(:tables => "ontap_storage_volume")
    h = {:label => label, :image => "100/ontap_storage_volume.png", :value => num}
    if num > 0 && role_allows?(:feature => "ontap_storage_volume_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => "ontap_storage_volumes")
    end
    h
  end

  def textual_file_shares
    num = @record.file_shares_size
    label = ui_lookup(:tables => "ontap_file_share")
    h = {:label => label, :image => "100/ontap_file_share.png", :value => num}
    if num > 0 && role_allows?(:feature => "ontap_file_share_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => "ontap_file_shares")
    end
    h
  end

  def textual_logical_disks
    num = @record.logical_disks_size
    label = ui_lookup(:tables => "ontap_logical_disk")
    h = {:label => label, :image => "100/ontap_logical_disk.png", :value => num}
    if num > 0 && role_allows?(:feature => "ontap_logical_disk_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => "ontap_logical_disks")
    end
    h
  end

  def textual_compliance_history
    super(:title => _("Show Compliance History of this %{title} (Last 10 Checks)") % {:title => host_title})
  end

  def textual_users
    return nil if @record.is_vmware_esxi?
    num = @record.number_of(:users)
    h = {:label => _("Users"), :image => "100/user.png", :value => num}
    if num > 0
      h[:title] = n_("Show the User defined on this VM", "Show the Users defined on this VM", num)
      h[:link]  = url_for(:action => 'users', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_groups
    return nil if @record.is_vmware_esxi?
    num = @record.number_of(:groups)
    h = {:label => _("Groups"), :image => "100/group.png", :value => num}
    if num > 0
      h[:title] = n_("Show the Group defined on this %{title}", "Show the Groups defined on this %{title}", num) %
        {:title => host_title}
      h[:link]  = url_for(:action => 'groups', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_firewall_rules
    return nil if @record.is_vmware_esxi?
    num = @record.number_of(:firewall_rules)
    h = {:label => _("Firewall Rules"), :image => "100/firewallrule.png", :value => num}
    if num > 0
      h[:title] = n_("Show the Firewall Rule defined on this %{title}",
                    "Show the Firewall Rules defined on this %{title}", num) % {:title => host_title}
      h[:link]  = url_for(:action => 'firewall_rules', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_ssh_root
    return nil if @record.is_vmware_esxi?
    {:label => _("SSH Root"), :value => @record.ssh_permit_root_login}
  end

  def textual_patches
    return nil if @record.is_vmware_esxi?
    num = @record.number_of(:patches)
    h = {:label => _("Patches"), :image => "100/patch.png", :value => num}
    if num > 0
      h[:title] = n_("Show the Patch defined on this %{title}", "Show the Patches defined on this %{title}", num) %
        {:title => host_title}
      h[:link]  = url_for(:action => 'patches', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_guest_applications
    num = @record.number_of(:guest_applications)
    h = {:label => _("Packages"), :image => "100/guest_application.png", :value => num}
    if num > 0
      h[:title] = n_("Show the Package installed on this %{title}",
                     "Show the Packages installed on this %{title}", num) % {:title => host_title}
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'guest_applications', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_host_services
    num = @record.number_of(:host_services)
    h = {:label => _("Services"), :image => "100/service.png", :value => num}
    if num > 0
      h[:title] = n_("Show the Service installed on this %{title}",
                     "Show the Services installed on this %{title}", num) % {:title => host_title}
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'host_services', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_filesystems
    num = @record.number_of(:filesystems)
    h = {:label => _("Files"), :image => "100/filesystems.png", :value => num}
    if num > 0
      h[:title] = n_("Show the File installed on this %{title}", "Show the Files installed on this %{title}", num) %
        {:title => host_title}
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'filesystems', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_advanced_settings
    num = @record.number_of(:advanced_settings)
    h = {:label => _("Advanced Settings"), :image => "100/advancedsetting.png", :value => num}
    if num > 0
      h[:title] = n_("Show the Advanced Setting installed on this %{title}",
                     "Show the Advanced Settings installed on this %{title}", num) % {:title => host_title}
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'advanced_settings', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_esx_logs
    num = @record.operating_system.nil? ? 0 : @record.operating_system.number_of(:event_logs)
    h = {:label => _("ESX Logs"), :image => "100/logs.png", :value => (num == 0 ? _("Not Available") : _("Available"))}
    if num > 0
      h[:title] = _("Show %{title} Network") % {:title => host_title}
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

  def textual_openstack_nova_scheduler
    {:label => _("Openstack Nova Scheduler"), :value => openstack_nova_scheduler_value,
     :link => url_for(:controller => controller.controller_name, :action => 'host_cloud_services', :id => @record)}
  end

  def openstack_nova_scheduler_value
    return _("Not available. Did you assigned Cloud Provider and run SSA?") if @record.cloud_services.empty?
    "%{enabled_cnt} Enabled / %{disabled_cnt} Disabled " % {
      :enabled_cnt  => @record.cloud_services.where(:scheduling_disabled => false).count,
      :disabled_cnt => @record.cloud_services.where(:scheduling_disabled => true).count
    }
  end

  def textual_introspected
    {:label => _("Introspected"), :value => @record.hardware.introspected}
  end

  def textual_provision_state
    {:label => _("Provisioning State"), :value => @record.hardware.provision_state}
  end

  def host_title
    title_for_host_record(@record)
  end
end
