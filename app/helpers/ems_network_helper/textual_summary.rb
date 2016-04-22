module EmsNetworkHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(provider_region hostname ipaddress type port guid)
  end

  def textual_group_relationships
    %i(parent_ems_cloud availability_zones cloud_tenants cloud_networks cloud_subnets network_routers security_groups
       floating_ips network_ports)
  end

  def textual_group_status
    textual_authentications + %i(refresh_status)
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
    {:label => _("Region"), :value => @ems.description}
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

  def textual_parent_ems_cloud
    textual_link(@record.parent_manager)
  end

  def textual_availability_zones
    @record.availability_zones
  end

  def textual_cloud_tenants
    @record.cloud_tenants
  end

  def textual_security_groups
    @record.security_groups
  end

  def textual_floating_ips
    @record.floating_ips
  end

  def textual_network_routers
    @record.network_routers
  end

  def textual_network_ports
    @record.network_ports
  end

  def textual_cloud_networks
    @record.cloud_networks
  end
  def textual_cloud_subnets
    @record.cloud_subnets
  end

  def textual_authentications
    authentications = @ems.authentication_for_summary
    return [{:label => _("Default Authentication"), :title => _("None"), :value => _("None")}] if authentications.blank?

    authentications.collect do |auth|
      label =
        case auth[:authtype]
        when "default" then "Default"
        when "metrics" then "C & U Database"
        when "amqp"    then "AMQP"
        else
          _("<Unknown>")
        end

      {:label => _("%{auth_type} Credentials") % {:auth_type => label},
       :value => auth[:status] || _("None"),
       :title => auth[:status_details]}
    end
  end

  def textual_refresh_status
    last_refresh_status = @ems.last_refresh_status.titleize
    if @ems.last_refresh_date
      last_refresh_date = time_ago_in_words(@ems.last_refresh_date.in_time_zone(Time.zone)).titleize
      last_refresh_status << _(" -%{last_refresh_date} Ago") % {:last_refresh_date => last_refresh_date}
    end
    {
      :label => _("Last Refresh"),
      :value => [{:value => last_refresh_status},
                 {:value => @ems.last_refresh_error.try(:truncate, 120)}],
      :title => @ems.last_refresh_error
    }
  end

  def textual_topology
    {:label => _('Topology'),
     :image => 'topology',
     :link  => url_for(:controller => 'network_topology', :action => 'show', :id => @ems.id),
     :title => _("Show topology")}
  end

  def textual_zone
    {:label => _("Managed by Zone"), :image => "zone", :value => @ems.zone.name}
  end
end
