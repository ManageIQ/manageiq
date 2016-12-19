module EmsNetworkHelper::TextualSummary
  include TextualMixins::TextualRefreshStatus
  #
  # Groups
  #

  def textual_group_properties
    %i(provider_region hostname ipaddress type port guid)
  end

  def textual_group_relationships
    %i(parent_ems_cloud cloud_networks cloud_subnets network_routers security_groups
       floating_ips network_ports load_balancers)
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
    {:label => _("Region"), :value => @ems.description}
  end

  def textual_hostname
    @ems.hostname
  end

  def textual_ipaddress
    return nil if @ems.ipaddress.blank?
    {:label => _("Discovered IP Address"), :value => @ems.ipaddress}
  end

  def textual_type
    {:label => _("Type"), :value => @ems.emstype_description}
  end

  def textual_port
    @ems.supports_port? ? {:label => _("API Port"), :value => @ems.port} : nil
  end

  def textual_guid
    {:label => _("Management Engine GUID"), :value => @ems.guid}
  end

  def textual_parent_ems_cloud
    {:label => _("Parent Cloud Provider"), :value => @record.try(:parent_manager)}
  end

  def textual_security_groups
    textual_link(@record.security_groups, :label => _("Security Groups"))
  end

  def textual_floating_ips
    textual_link(@record.floating_ips, :label => _("Floating IPs"))
  end

  def textual_network_routers
    textual_link(@record.network_routers, :label => _("Network Routers"))
  end

  def textual_network_ports
    textual_link(@record.network_ports, :label => _("Network Ports"))
  end

  def textual_load_balancers
    textual_link(@record.load_balancers, :label => _("Load Balancers"))
  end

  def textual_cloud_networks
    textual_link(@record.cloud_networks, :label => _("Cloud Networks"))
  end
  def textual_cloud_subnets
    textual_link(@record.cloud_subnets, :label => _("Cloud Subnets"))
  end

  def textual_topology
    {:label => _('Topology'),
     :icon  => "pficon pficon-topology",
     :link  => url_for(:controller => 'network_topology', :action => 'show', :id => @ems.id),
     :title => _("Show topology")}
  end

  def textual_zone
    {:label => _("Managed by Zone"), :icon => "pficon pficon-zone", :value => @ems.zone.try(:name)}
  end
end
