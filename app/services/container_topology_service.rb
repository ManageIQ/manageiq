class ContainerTopologyService
  def initialize(provider_id)
    @provider_id = provider_id
  end

  def build_topology
    nodes, services = entities
    topology = {}
    topo_items = {}
    links = []
    nodes.each do |n|
      topo_items[n.ems_ref] = build_entity_data(n, "Node")
      n.container_groups.each do |cg|
        topo_items[cg.ems_ref] = build_entity_data(cg, "Pod")
        links << build_link(n.ems_ref, cg.ems_ref)
        cg.containers.each do |c|
          topo_items[c.ems_ref] = build_entity_data(c, "Container")
          links << build_link(cg.ems_ref, c.ems_ref)
        end
        if cg.container_replicator
          cr = cg.container_replicator
          topo_items[cr.ems_ref] = build_entity_data(cr, "Replicator")
          links << build_link(cg.ems_ref, cr.ems_ref)
        end
      end

      if n.lives_on
        kind = n.lives_on.kind_of?(Vm) ? "VM" : "Host"
        topo_items[n.lives_on.uid_ems] = build_entity_data(n.lives_on, kind)
        links << build_link(n.ems_ref, n.lives_on.uid_ems)
        if kind == 'VM' # add link to Host
          host = n.lives_on.host
          topo_items[host.uid_ems] = build_entity_data(host, "Host")
          links << build_link(n.lives_on.uid_ems, host.uid_ems)
        end
      end
    end

    services.each do |s|
      topo_items[s.ems_ref] = build_entity_data(s, "Service")
      s.container_groups.each { |cg| links << build_link(s.ems_ref, cg.ems_ref) } if s.container_groups.size > 0
    end

    topology[:items] = topo_items
    topology[:relations] = links
    topology[:kinds] = build_kinds
    topology
  end

  def build_entity_data(entity, kind)
    status = entity_status(entity, kind)

    id = case kind
         when 'VM', 'Host' then entity.uid_ems
         else entity.ems_ref
         end

    {:metadata => {:id => id}, :name => entity.name, :status => status, :kind => kind}
  end

  def entity_status(entity, kind)
    case kind
    when 'VM', 'Host' then entity.power_state
    when 'Node'
      condition = entity.container_conditions.first
      if condition.name == 'Ready' && condition.status == 'True'
        'Ready'
      else
        'NotReady'
      end
    when 'Pod' then entity.phase
    when 'Container' then entity.state
    else 'unknown'
    end
  end

  def build_link(source, target)
    {:source => source, :target => target}
  end

  def entities
    # provider id is empty when the topology is generated for all the providers together
    if @provider_id
      provider = ExtManagementSystem.find(@provider_id.to_i)
      if provider.kind_of?(ManageIQ::Providers::Openshift::ContainerManager) || provider.kind_of?(ManageIQ::Providers::Kubernetes::ContainerManager)
        nodes = provider.container_nodes
        services = provider.container_services
      else
        nodes = ContainerNode.all
        services = ContainerService.all
      end
    else
      nodes = ContainerNode.all
      services = ContainerService.all
    end
    [nodes, services]
  end

  def build_kinds
    {:Replicator => true,
     :Pod        => true,
     :Container  => true,
     :Node       => true,
     :Service    => true,
     :Host       => true,
     :VM         => true
    }
  end
end
