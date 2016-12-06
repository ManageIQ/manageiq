class NetworkTopologyService < TopologyService
  include UiServiceMixin

  @provider_class = ManageIQ::Providers::NetworkManager

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

    included_relations = [
      :tags,
      :cloud_subnets => [
        :parent_cloud_subnet,
        :tags,
        :cloud_network  => :tags,
        :vms            => [
          :tags,
          :load_balancers  => :tags,
          :floating_ips    => :tags,
          :cloud_tenant    => :tags,
          :security_groups => :tags],
        :network_router => [
          :tags,
          :cloud_network => [
            :floating_ips => :tags
          ]
        ]]]

    entity_relationships = {:NetworkManager => build_entity_relationships(included_relations)}

    preloaded = @providers.includes(included_relations)

    preloaded.each do |entity|
      topo_items, links = build_recursive_topology(entity, entity_relationships[:NetworkManager], topo_items, links)
    end

    populate_topology(topo_items, links, build_kinds, icons)
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
      entity.authentications.blank? ? 'Unknown' : entity.authentications.first.status.try(:capitalize)
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
             :SecurityGroup, :LoadBalancer, :Tag]
    build_legend_kinds(kinds)
  end
end
