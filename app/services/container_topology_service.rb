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
      topo_items[n.ems_ref] = build_entity(n.ems_ref, n.name, "Node")
      n.container_groups.each do |cg|
        topo_items[cg.ems_ref] = build_entity(cg.ems_ref, cg.name, "Pod")
        links << build_link(n.ems_ref, cg.ems_ref)
        cg.containers.each do |c|
          topo_items[c.ems_ref] = build_entity(c.ems_ref, c.name, "Container")
          links << build_link(cg.ems_ref, c.ems_ref)
        end
      end

      if n.lives_on
        kind = n.lives_on.kind_of?(Vm) ? "VM" : "Host"
        topo_items[n.lives_on.uid_ems] = build_entity(n.lives_on.uid_ems, n.lives_on.name, kind)
        links << build_link(n.ems_ref, n.lives_on.uid_ems)
        if kind == 'VM' # add link to Host
          host = n.lives_on.host
          topo_items[host.uid_ems] = build_entity(host.uid_ems, host.name, "Host")
          links << build_link(n.lives_on.uid_ems, host.uid_ems)
        end
      end
    end

    services.each do |s|
      topo_items[s.ems_ref] = build_entity(s.ems_ref, s.name, "Service")
      s.container_groups.each { |cg| links << build_link(s.ems_ref, cg.ems_ref) } if s.container_groups.size > 0
    end

    topology[:items] = topo_items
    topology[:relations] = links
    topology[:kinds] = build_kinds
    topology
  end

  def build_entity(id, name, kind)
    {:metadata => {:id => id, :name => name}, :kind => kind}
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
    {:Pod            => '#vertex-Pod',
     :Container      => '#vertex-Container',
     :Node           => '#vertex-Node',
     :Service        => '#vertex-Service',
     :Host           => '#vertex-Host',
     :VM             => '#vertex-VM'
    }
  end
end
