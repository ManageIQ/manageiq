class ContainerTopologyService
  include ActionView::Helpers::AssetUrlHelper

  def initialize(provider_id)
    @provider_id = provider_id
    @providers = retrieve_providers
  end

  def build_topology
    topology = {}
    topo_items = {}
    links = []

    @providers.each do |provider|
      topo_items[entity_id(provider)] =  build_entity_data(provider)
      provider.container_nodes.each { |n|
        topo_items[entity_id(n)] = build_entity_data(n)
        links << build_link(entity_id(provider), entity_id(n))
        n.container_groups.each do |cg|
          topo_items[entity_id(cg)] = build_entity_data(cg)
          links << build_link(entity_id(n), entity_id(cg))
          cg.containers.each do |c|
            topo_items[entity_id(c)] = build_entity_data(c)
            links << build_link(entity_id(cg), entity_id(c))
          end
          if cg.container_replicator
            cr = cg.container_replicator
            topo_items[entity_id(cr)] = build_entity_data(cr)
            links << build_link(entity_id(cr), entity_id(cg))
          end
        end

        if n.lives_on
          kind = entity_type(n.lives_on)
          topo_items[entity_id(n.lives_on)] = build_entity_data(n.lives_on)
          links << build_link(entity_id(n), entity_id(n.lives_on))
          if kind == 'Vm' # add link to Host
            host = n.lives_on.host
            if host
              topo_items[entity_id(host)] = build_entity_data(host)
              links << build_link(entity_id(n.lives_on), entity_id(host))
            end
          end
        end
      }

      provider.container_services.each { |s|
        topo_items[entity_id(s)] = build_entity_data(s)
        s.container_groups.each { |cg| links << build_link(entity_id(s), entity_id(cg)) } if s.container_groups.size > 0
        if s.container_routes.size > 0
          s.container_routes.each { |r|
            topo_items[entity_id(r)] = build_entity_data(r)
            links << build_link(entity_id(s), entity_id(r))
          }
        end
      }
    end

    topology[:items] = topo_items
    topology[:relations] = links
    topology[:kinds] = build_kinds
    topology
  end
  
  def entity_type(entity)
      entity.class.name.demodulize
  end

  def entity_display_type(entity)
    if entity.kind_of?(ManageIQ::Providers::ContainerManager)
      entity.type.split('::')[2]
    elsif entity.kind_of?(ManageIQ::Providers::ContainerManager::ContainerGroup)
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

  def entity_id(entity)
    if entity.kind_of?(ManageIQ::Providers::ContainerManager)
      id = entity.id.to_s
    elsif entity.kind_of?(Host) || entity.kind_of?(Vm)
      id = entity.uid_ems
    else
      id = entity.ems_ref
    end
    id
  end

  def build_entity_data(entity)
    type = entity_type(entity)
    status = entity_status(entity, type)
    data = {:id           => entity_id(entity),
            :name         => entity.name,
            :status       => status,
            :kind         => type,
            :display_kind => entity_display_type(entity),
            :miq_id       => entity.id}

    if entity.kind_of?(Host) || entity.kind_of?(Vm)
      data.merge!(:provider => entity.ext_management_system.name)
    end

    data
  end

  def entity_status(entity, kind)
    case kind
    when 'Vm', 'Host' then entity.power_state.capitalize
    when 'ContainerNode'
      ready_status = 'Unknown'
      entity.container_conditions.each do |condition|
        if condition.try(:name) == 'Ready' && condition.try(:status) == 'True'
          ready_status = 'Ready'
        else
          ready_status = 'NotReady'
        end
      end
      ready_status
    when 'ContainerGroup' then entity.phase
    when 'Container' then entity.state.capitalize
    when 'ContainerReplicator'
      if entity.current_replicas == entity.replicas
        'OK'
      else
        'Warning'
      end
    when 'ContainerManager'
      if entity.authentications.empty?
        'Unknown'
      else
        entity.authentications.first.status.capitalize
      end
    else 'Unknown'
    end
  end

  def build_link(source, target)
    {:source => source, :target => target}
  end

  def retrieve_providers
    if @provider_id
      providers = ManageIQ::Providers::ContainerManager.where(:id => @provider_id)
    else  # provider id is empty when the topology is generated for all the providers together
      providers = ManageIQ::Providers::ContainerManager.all
    end
    providers
  end

  def build_kinds
    kinds = [:ContainerReplicator, :ContainerGroup, :Container, :ContainerNode,
             :ContainerService, :Host, :Vm, :ContainerRoute]

    if @providers.size > 0
      kinds << :ContainerManager
    end
    kinds.each_with_object({}) { |kind, h| h[kind] = true }
  end
end
