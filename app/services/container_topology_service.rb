class ContainerTopologyService < TopologyService
  include UiServiceMixin

  @provider_class = ManageIQ::Providers::ContainerManager

  def build_topology
    topo_items = {}
    links = []

    entity_relationships = {:ContainerManager => {:ContainerNodes =>
                                                      {:ContainerGroups =>
                                                         {:Containers => nil, :ContainerReplicator => nil, :ContainerServices => {:ContainerRoutes => nil}},
                                                       :lives_on => {:Host => nil}
                                                   }}}

    preloaded = @providers.includes(:container_nodes => [:container_groups => [:containers, :container_replicator, :container_services => [:container_routes]],
                                                         :lives_on => [:host]])
    preloaded.each do |entity|
      topo_items, links = build_recursive_topology(entity, entity_relationships[:ContainerManager], topo_items, links)
    end

    populate_topology(topo_items, links, build_kinds, icons)
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

    if (entity.kind_of?(Host) || entity.kind_of?(Vm)) && entity.ext_management_system.present?
      data.merge!(:provider => entity.ext_management_system.name)
    end

    data
  end

  def entity_status(entity)
    if entity.kind_of?(Host) || entity.kind_of?(Vm)
      status = entity.power_state.capitalize
    elsif entity.kind_of?(ContainerNode)
      node_ready_status = entity.container_conditions.find_by_name('Ready').try(:status)
      status = case node_ready_status
               when 'True'
                 'Ready'
               when 'False'
                 'NotReady'
               else
                 'Unknown'
               end
    elsif entity.kind_of?(ContainerGroup)
      status = entity.phase
    elsif entity.kind_of?(Container)
      status = entity.state.capitalize
    elsif entity.kind_of?(ContainerReplicator)
      status = (entity.current_replicas == entity.replicas) ? 'OK' : 'Warning'
    elsif entity.kind_of?(ManageIQ::Providers::ContainerManager)
      status = entity.authentications.empty? ? 'Unknown' : entity.default_authentication.status.capitalize
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
