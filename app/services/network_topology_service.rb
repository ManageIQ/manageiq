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

    entity_relationships = {
      :NetworkManager => {
        :CloudSubnets => {
          :CloudNetwork  => nil,
          :Vms => {
            :FloatingIps    => nil,
            :CloudTenant    => nil,
            :SecurityGroups => nil
          },
          :NetworkRouter => {
            :CloudNetwork => {
              :FloatingIps => nil}
          },
        }
      },
    }

    preloaded = @providers.includes(:cloud_subnets => [:cloud_network,
                                                       :vms => [
                                                         :floating_ips,
                                                         :cloud_tenant,
                                                         :security_groups],
                                                       :network_router => [
                                                         :cloud_network => [
                                                           :floating_ips
                                                         ]
                                                       ]])
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
      status = entity.power_state.capitalize
    when ManageIQ::Providers::NetworkManager
      status = entity.authentications.empty? ? 'Unknown' : entity.authentications.first.status.capitalize
    when NetworkRouter, CloudSubnet, CloudNetwork, FloatingIp
      status = entity.status ? entity.status.downcase.capitalize : 'Unknown'
    when CloudTenant
      status = entity.enabled? ? "OK" : "Unknown"
    else
      status = 'Unknown'
    end
    status
  end

  def build_kinds
    kinds = [:NetworkRouter, :CloudSubnet, :Vm, :NetworkManager, :FloatingIp, :CloudNetwork, :NetworkPort, :CloudTenant,
             :SecurityGroup]
    build_legend_kinds(kinds)
  end
end
