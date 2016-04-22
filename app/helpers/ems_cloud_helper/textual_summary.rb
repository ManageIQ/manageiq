module EmsCloudHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(provider_region hostname ipaddress type port guid keystone_v3_domain_id)
  end

  def textual_group_relationships
    %i(ems_infra network_manager availability_zones cloud_tenants flavors security_groups
       instances images orchestration_stacks cloud_volumes cloud_object_store_containers)
  end

  def textual_group_status
    textual_authentications + %i(refresh_status)
  end

  def textual_group_smart_management
    %i(zone tags)
  end

  def textual_group_topology
  end

  #
  # Items
  #
  def textual_provider_region
    return nil if @ems.provider_region.nil?
    label_val = (@ems.type.include? "Google") ? _("Preferred Region") : _("Region")
    {:label => label_val, :value => @ems.description}
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
    return nil if @ems.kind_of?(ManageIQ::Providers::Amazon::CloudManager)
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
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link]  = ems_cloud_path(@ems.id, :display => 'instances')
      h[:title] = _("Show all %{label}") % {:label => label}
    end
    h
  end

  def textual_images
    label = ui_lookup(:tables => "template_cloud")
    num = @ems.number_of(:miq_templates)
    h = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "miq_template_show_list")
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

  def textual_availability_zones
    @record.availability_zones
  end

  def textual_cloud_tenants
    @record.cloud_tenants
  end

  def textual_cloud_volumes
    @record.cloud_volumes
  end

  def textual_cloud_object_store_containers
    label = ui_lookup(:tables => "cloud_object_store_container")
    num = @ems.number_of(:cloud_object_store_containers)
    h = {:label => label, :image => "cloud_object_store_container", :value => num}
    if num > 0 && role_allows(:feature => "cloud_object_store_container_show_list")
      h[:link] = ems_cloud_path(@ems.id, :display => 'cloud_object_store_containers')
      h[:title] = _("Show all %{label}") % {:label => label}
    end
    h
  end

  def textual_orchestration_stacks
    @record.orchestration_stacks
  end

  def textual_flavors
    @record.flavors
  end

  def textual_security_groups
    @record.security_groups
  end

  def textual_authentications
    authentications = @ems.authentication_for_summary
    return [{:label => _("Default Authentication"), :title => _("None"), :value => _("None")}] if authentications.blank?

    authentications.collect do |auth|
      label =
        case auth[:authtype]
        when "default" then _("Default")
        when "metrics" then _("C & U Database")
        when "amqp"    then _("AMQP")
        else;               _("<Unknown>")
        end

      {:label => _("%{label} Credentials") % {:label => label},
       :value => auth[:status] || _("None"),
       :title => auth[:status_details]}
    end
  end

  def textual_refresh_status
    last_refresh_status = @ems.last_refresh_status.titleize
    if @ems.last_refresh_date
      last_refresh_date = time_ago_in_words(@ems.last_refresh_date.in_time_zone(Time.zone)).titleize
      last_refresh_status << " - #{last_refresh_date} Ago"
    end
    {
      :label => _("Last Refresh"),
      :value => [{:value => last_refresh_status},
                 {:value => @ems.last_refresh_error.try(:truncate, 120)}],
      :title => @ems.last_refresh_error
    }
  end

  def textual_zone
    {:label => _("Managed by Zone"), :image => "zone", :value => @ems.zone.name}
  end
end
