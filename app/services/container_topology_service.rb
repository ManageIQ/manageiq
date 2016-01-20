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
      topo_items[provider.id.to_s] =  build_entity_data(provider)
      provider.container_nodes.each { |n|
        topo_items[n.ems_ref] = build_entity_data(n)
        links << build_link(provider.id.to_s, n.ems_ref)
        n.container_groups.each do |cg|
          topo_items[cg.ems_ref] = build_entity_data(cg)
          links << build_link(n.ems_ref, cg.ems_ref)
          cg.containers.each do |c|
            topo_items[c.ems_ref] = build_entity_data(c)
            links << build_link(cg.ems_ref, c.ems_ref)
          end
          if cg.container_replicator
            cr = cg.container_replicator
            topo_items[cr.ems_ref] = build_entity_data(cr)
            links << build_link(cg.ems_ref, cr.ems_ref)
          end
        end

        if n.lives_on
          kind = entity_type(n.lives_on)
          topo_items[n.lives_on.uid_ems] = build_entity_data(n.lives_on)
          links << build_link(n.ems_ref, n.lives_on.uid_ems)
          if kind == 'Vm' # add link to Host
            host = n.lives_on.host
            if host
              topo_items[host.uid_ems] = build_entity_data(host)
              links << build_link(n.lives_on.uid_ems, host.uid_ems)
            end
          end
        end
      }

      provider.container_services.each { |s|
        topo_items[s.ems_ref] = build_entity_data(s)
        s.container_groups.each { |cg| links << build_link(s.ems_ref, cg.ems_ref) } if s.container_groups.size > 0
        if s.container_routes.size > 0
          s.container_routes.each { |r|
            topo_items[r.ems_ref] = build_entity_data(r)
            links << build_link(s.ems_ref, r.ems_ref)
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
        if name.eql? "Vm"
          'VM'
        else
          name # non container entities such as Host, Vm
        end
      end
    end
  end

  def build_entity_data(entity)
    type = entity_type(entity)
    status = entity_status(entity, type)

    if entity.kind_of?(ManageIQ::Providers::ContainerManager)
      id = entity.id.to_s
    else
      id = case type
           when 'Vm', 'Host'
             entity.uid_ems
           else
             entity.ems_ref
           end
    end

    data = {:id           => id,
            :name         => entity.name,
            :status       => status,
            :kind         => type,
            :display_kind => entity_display_type(entity),
            :miq_id       => entity.id}

    if %w(Vm Host).include? type
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
