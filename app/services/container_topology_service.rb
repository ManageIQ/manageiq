class ContainerTopologyService
  def initialize(provider_id)
    @provider_id = provider_id
    @providers = retrieve_providers
  end

  def build_topology
    topology = {}
    topo_items = {}
    links = []

    @providers.each do |provider|
      topo_items[provider.id.to_s] =  build_entity_data(provider, provider.type.split('::')[2])
      provider.container_nodes.each { |n|
          topo_items[n.ems_ref] = build_entity_data(n, "Node")
          links << build_link(provider.id.to_s, n.ems_ref)
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
            if host
              topo_items[host.uid_ems] = build_entity_data(host, "Host")
              links << build_link(n.lives_on.uid_ems, host.uid_ems)
            end
          end
        end
      }

      provider.container_services.each { |s|
        topo_items[s.ems_ref] = build_entity_data(s, "Service")
        s.container_groups.each { |cg| links << build_link(s.ems_ref, cg.ems_ref) } if s.container_groups.size > 0
        if s.container_routes.size > 0
          s.container_routes.each { |r|
            topo_items[r.ems_ref] = build_entity_data(r, "Route")
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

  def build_entity_data(entity, kind)
    status = entity_status(entity, kind)
    id = case kind
           when 'VM', 'Host' then entity.uid_ems
           when 'Kubernetes', 'Openshift', 'Atomic', 'OpenshiftEnterprise' then entity.id.to_s
         else entity.ems_ref
         end

    data = {:id => id, :name => entity.name, :status => status, :kind => kind, :miq_id => entity.id}
    if (kind.eql?("VM") || kind.eql?("Host"))
      data.merge!(:provider => entity.ext_management_system.name)
    end
    data
  end

  def entity_status(entity, kind)
    case kind
    when 'VM', 'Host' then entity.power_state.capitalize
    when 'Node'
      condition = entity.container_conditions.first
      if condition.name == 'Ready' && condition.status == 'True'
        'Ready'
      else
        'NotReady'
      end
    when 'Pod' then entity.phase
    when 'Container' then entity.state.capitalize
    when 'Replicator'
      if entity.current_replicas == entity.replicas
        'OK'
      else
        'Warning'
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
    kinds =  { :Replicator => true,
               :Pod        => true,
               :Container  => true,
               :Node       => true,
               :Service    => true,
               :Host       => true,
               :VM         => true,
               :Route      => true
             }
    if @providers.any? { |instance| instance.kind_of?(ManageIQ::Providers::Kubernetes::ContainerManager) }
      kinds.merge!(:Kubernetes => true)
    end
    if @providers.any? { |instance| instance.kind_of?(ManageIQ::Providers::Openshift::ContainerManager) }
      kinds.merge!(:Openshift => true)
    end
    if @providers.any? { |instance| instance.kind_of?(ManageIQ::Providers::Atomic::ContainerManager) }
      kinds.merge!(:Atomic => true)
    end
    if @providers.any? { |instance| instance.kind_of?(ManageIQ::Providers::OpenshiftEnterprise::ContainerManager) }
      kinds.merge!(:OpenshiftEnterprise => true)
    end
    kinds
  end
end
