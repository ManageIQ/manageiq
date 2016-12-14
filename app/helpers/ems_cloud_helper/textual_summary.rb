module EmsCloudHelper::TextualSummary
  include TextualMixins::TextualRefreshStatus
  #
  # Groups
  #

  def textual_group_properties
    %i(provider_region hostname ipaddress type port guid region keystone_v3_domain_id)
  end

  def textual_group_relationships
    %i(ems_infra network_manager availability_zones host_aggregates cloud_tenants flavors
       security_groups instances images orchestration_stacks storage_managers)
  end

  def textual_group_configuration_relationships
    %i(arbitration_profiles)
  end

  def textual_group_status
    textual_authentications(@ems.authentication_for_summary) + %i(refresh_status)
  end

  def textual_group_smart_management
    %i(zone tags)
  end

  def textual_group_topology
    items = %w(topology)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #
  def textual_provider_region
    return nil if @ems.provider_region.nil?
    label_val = (@ems.type.include? "Google") ? _("Preferred Region") : _("Region")
    {:label => label_val, :value => @ems.description}
  end

  def textual_region
    return nil if @ems.provider_region.blank?
    label_val = _('Region')
    {:label => label_val, :value => @ems.provider_region}
  end

  def textual_keystone_v3_domain_id
    return nil if !@ems.respond_to?(:keystone_v3_domain_id) || @ems.keystone_v3_domain_id.nil?
    label_val = _("Keystone V3 Domain ID")
    {:label => label_val, :value => @ems.keystone_v3_domain_id}
  end

  def textual_hostname
    @ems.hostname
  end

  def textual_ipaddress
    return nil if @ems.ipaddress.blank?
    {:label => _("Discovered IP Address"), :value => @ems.ipaddress}
  end

  def textual_type
    @ems.emstype_description
  end

  def textual_port
    @ems.supports_port? ? {:label => _("API Port"), :value => @ems.port} : nil
  end

  def textual_guid
    {:label => _("Management Engine GUID"), :value => @ems.guid}
  end

  def textual_instances
    label = ui_lookup(:tables => "vm_cloud")
    num   = @ems.number_of(:vms)
    h     = {:label => label, :image => "100/vm.png", :value => num}
    if num > 0 && role_allows?(:feature => "vm_show_list")
      h[:link]  = ems_cloud_path(@ems.id, :display => 'instances')
      h[:title] = _("Show all %{label}") % {:label => label}
    end
    h
  end

  def textual_images
    label = ui_lookup(:tables => "template_cloud")
    num = @ems.number_of(:miq_templates)
    h = {:label => label, :image => "100/vm.png", :value => num}
    if num > 0 && role_allows?(:feature => "miq_template_show_list")
      h[:link] = ems_cloud_path(@ems.id, :display => 'images')
      h[:title] = _("Show all %{label}") % {:label => label}
    end
    h
  end

  def textual_ems_infra
    textual_link(@record.try(:provider).try(:infra_ems))
  end

  def textual_network_manager
    textual_link(@record.ext_management_system.try(:network_manager))
  end

  def textual_storage_managers
    label = _("Storage Managers")
    num   = @ems.try(:storage_managers) ?  @ems.number_of(:storage_managers) : 0
    h     = {:label => label, :image => "100/storage_manager.png", :value => num}
    if num > 0 && role_allows?(:feature => "ems_storage_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:link] = ems_cloud_path(@ems.id, :display => 'storage_managers')
    end
    h
  end

  def textual_availability_zones
    @record.availability_zones
  end

  def textual_host_aggregates
    @record.host_aggregates
  end

  def textual_cloud_tenants
    @record.cloud_tenants
  end

  def textual_orchestration_stacks
    @record.orchestration_stacks
  end

  def textual_flavors
    @record.flavors
  end

  def textual_security_groups
    label = ui_lookup(:tables => "security_group")
    num = @ems.number_of(:security_groups)
    h = {:label => label, :image => "100/security_group.png", :value => num}
    if num > 0 && role_allows?(:feature => "security_group_show_list")
      h[:link] = ems_cloud_path(@ems.id, :display => 'security_groups')
      h[:title] = _("Show all %{label}") % {:label => label}
    end
    h
  end

  def textual_arbitration_profiles
    num = @record.number_of(:arbitration_profiles)
    h = {:label => _("Arbitration Profiles"), :image => "100/arbitration_profile.png", :value => num}
    if num > 0
      h[:title] = n_("Show Arbitration Profiles for this Provider",
                     "Show Arbitration Profiles for this Provider", num)
      h[:link]  = url_for(:controller => controller.controller_name,
                          :action     => 'arbitration_profiles',
                          :id         => @record,
                          :db         => controller.controller_name)
    end
    h
  end

  def textual_zone
    {:label => _("Managed by Zone"), :image => "100/zone.png", :value => @ems.zone.name}
  end

  def textual_topology
    {:label => _('Topology'),
     :image => '100/topology.png',
     :link  => url_for(:controller => 'cloud_topology', :action => 'show', :id => @ems.id),
     :title => _("Show topology")}
  end
end
