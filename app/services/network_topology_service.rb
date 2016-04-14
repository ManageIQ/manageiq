class NetworkTopologyService < TopologyService
  def initialize(provider_id)
    @provider_id = provider_id
    @providers = retrieve_providers(ManageIQ::Providers::NetworkManager, @provider_id)
  end

  def entity_type(entity)
    if entity.kind_of?(CloudNetwork)
      entity.class.base_class.name.demodulize
    else
      entity.class.name.demodulize
    end
  end

  def build_topology
    topo_items = {}
    links = []

    included_relations = {
      :cloud_subnets => [
        :tags,
        :cloud_network => :tags,
        :vms => [
          :tags,
          :floating_ips    => :tags,
          :cloud_tenant    => :tags,
          :security_groups => :tags],
        :network_router => [
          :tags,
          :cloud_network => [
            :floating_ips => :tags
          ]
        ]]}

    entity_relationships = {:NetworkManager => build_entity_relationships(included_relations)}

    preloaded = @providers.includes(included_relations)

    preloaded.each do |entity|
      topo_items, links = build_recursive_topology(entity, entity_relationships[:NetworkManager], topo_items, links)
    end

    icons = {:CloudSubnet   => {:type => "glyph", :icon => "\uE909", :fontfamily => "PatternFlyIcons-webfont"}, # pficon-network
             :NetworkRouter => {:type => "glyph", :icon => "\uE625", :fontfamily => "PatternFlyIcons-webfont"}, # pficon-route
             :SecurityGroup => {:type => "glyph", :icon => "\uE903", :fontfamily => "PatternFlyIcons-webfont"}, # pficon-cloud-security
             :FloatingIp    => {:type => "glyph", :icon => "\uF041", :fontfamily => "FontAwesome"},             # fa-map-marker
             :CloudNetwork  => {:type => "glyph", :icon => "\uE62c", :fontfamily => "IcoMoon"},
             :CloudTenant   => {:type => "glyph", :icon => "\uE904", :fontfamily => "PatternFlyIcons-webfont"}, # pficon-cloud-tenant
             :Vm            => {:type => "glyph", :icon => "\uE90f", :fontfamily => "PatternFlyIcons-webfont"}, # pficon-virtual-machine
             :Tag           => {:type => "glyph", :icon => "\uF02b", :fontfamily => "FontAwesome"},
             :Openstack     => {:type => "image", :icon => provider_icon(:Openstack)},
             :Amazon        => {:type => "image", :icon => provider_icon(:Amazon)},
             :Azure         => {:type => "image", :icon => provider_icon(:Azure)},
             :Google        => {:type => "image", :icon => provider_icon(:Google)},
    }

    populate_topology(topo_items, links, build_kinds, icons)
  end

  def provider_icon(provider_type)
    file_name = 'svg/vendor-' + provider_type.to_s.underscore.downcase + '.svg'
    ActionController::Base.helpers.image_path(file_name)
  end

  def entity_display_type(entity)
    if entity.kind_of?(ManageIQ::Providers::NetworkManager)
      entity.class.short_token
    else
      name = entity.class.name.demodulize
      if entity.kind_of?(Vm)
        name.upcase # turn Vm to VM because it's an abbreviation
      elsif ['Public', 'Private'].include?(name) && entity.kind_of?(CloudNetwork)
        entity_type(entity) + " " + name
      else
        name
      end
    end
  end

  def build_entity_data(entity)
    data = build_base_entity_data(entity)
    data[:status]       = entity_status(entity)
    data[:display_kind] = entity_display_type(entity)

    if entity.kind_of?(Host) || entity.kind_of?(Vm)
      data[:provider] = entity.ext_management_system.name
    end

    data
  end

  def entity_status(entity)
    case entity
    when Vm
      entity.power_state.capitalize
    when ManageIQ::Providers::NetworkManager
      entity.authentications.empty? ? 'Unknown' : entity.authentications.first.status.capitalize
    when NetworkRouter, CloudSubnet, CloudNetwork, FloatingIp
      entity.status ? entity.status.downcase.capitalize : 'Unknown'
    when CloudTenant
      entity.enabled? ? "OK" : "Unknown"
    else
      'Unknown'
    end
  end

  def build_kinds
    kinds = [:NetworkRouter, :CloudSubnet, :Vm, :NetworkManager, :FloatingIp, :CloudNetwork, :NetworkPort, :CloudTenant,
             :SecurityGroup, :Tag]
    build_legend_kinds(kinds)
  end
end
