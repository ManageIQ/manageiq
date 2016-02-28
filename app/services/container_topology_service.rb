class ContainerTopologyService < TopologyService

  def initialize(provider_id)
    @provider_id = provider_id
    @providers = retrieve_providers(@provider_id, ManageIQ::Providers::ContainerManager)
  end

  def build_topology
    topo_items = {}
    links = []

    @providers.each do |provider|
      topo_items[key = entity_id(provider)] = build_entity_data(provider)
      provider.container_nodes.each { |n|
        topo_items[entity_id(n)] = build_entity_data(n)
        links << build_link(key, entity_id(n))
        n.container_groups.each do |cg|
          topo_items[key = entity_id(cg)] = build_entity_data(cg)
          links << build_link(entity_id(n), key)
          cg.containers.each do |c|
            topo_items[key = entity_id(c)] = build_entity_data(c)
            links << build_link(entity_id(cg), key)
          end
          if cg.container_replicator
            cr = cg.container_replicator
            topo_items[key = entity_id(cr)] = build_entity_data(cr)
            links << build_link(key, entity_id(cg))
          end
        end

        if n.lives_on
          topo_items[key = entity_id(n.lives_on)] = build_entity_data(n.lives_on)
          links << build_link(entity_id(n), key)
          if n.lives_on.kind_of?(Vm) # add link to Host
            host = n.lives_on.host
            if host
              topo_items[key = entity_id(host)] = build_entity_data(host)
              links << build_link(entity_id(n.lives_on), key)
            end
          end
        end
      }

      provider.container_services.each { |s|
        topo_items[key = entity_id(s)] = build_entity_data(s)
        s.container_groups.each { |cg| links << build_link(key, entity_id(cg)) } if s.container_groups.size > 0
        if s.container_routes.size > 0
          s.container_routes.each { |r|
            topo_items[key = entity_id(r)] = build_entity_data(r)
            links << build_link(entity_id(s), key)
          }
        end
      }
    end

    populate_topology(topo_items, links, build_kinds)
  end

  def entity_display_type(entity)
    if entity.kind_of?(ManageIQ::Providers::ContainerManager)
      entity.class.short_token
    elsif entity.kind_of?(ContainerGroup)
      "Pod"
    else
      name = entity.class.name.demodulize
      if name.start_with? "Container"
        if name.length > "Container".length # container related entities such as ContainerService
          name["Container".length..-1]
        else
          "Container" # the container entity itself
        end
      else
        if entity.kind_of?(Vm)
          name.upcase # turn Vm to VM because it's an abbreviation
        else
          name # non container entities such as Host
        end
      end
    end
  end

  def build_entity_data(entity)
    data = build_base_entity_data(entity)
    data.merge!(:status       => entity_status(entity),
                :display_kind => entity_display_type(entity))

    if entity.kind_of?(Host) || entity.kind_of?(Vm)
      data.merge!(:provider => entity.ext_management_system.name)
    end

    data
  end

  def entity_status(entity)
    if entity.kind_of?(Host) || entity.kind_of?(Vm)
      status = entity.power_state.capitalize
    elsif entity.kind_of?(ContainerNode)
      status = 'Unknown'
      entity.container_conditions.each do |condition|
        if condition.try(:name) == 'Ready' && condition.try(:status) == 'True'
          status = condition.name
        else
          status = 'NotReady'
        end
      end
    elsif entity.kind_of?(ContainerGroup)
      status = entity.phase
    elsif entity.kind_of?(Container)
      status = entity.state.capitalize
    elsif entity.kind_of?(ContainerReplicator)
      status = (entity.current_replicas == entity.replicas) ? 'OK' : 'Warning'
    elsif entity.kind_of?(ManageIQ::Providers::ContainerManager)
      status = entity.authentications.empty? ? 'Unknown' : entity.authentications.first.status.capitalize
    else
      status = 'Unknown'
    end
    status
  end

  def build_kinds
    kinds = [:ContainerReplicator, :ContainerGroup, :Container, :ContainerNode,
             :ContainerService, :Host, :Vm, :ContainerRoute, :ContainerManager]
    build_legend_kinds(kinds)
  end
end
