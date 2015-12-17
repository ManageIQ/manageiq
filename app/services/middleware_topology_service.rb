class MiddlewareTopologyService
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
      provider.middleware_servers.each { |n|
          topo_items[n.ems_ref] = build_entity_data(n, "MiddlewareServer")
          links << build_link(provider.id.to_s, n.ems_ref)
          n.middleware_deployments.each do |cg|
            topo_items[cg.ems_ref] = build_entity_data(cg, "MiddlewareDeployment")
            links << build_link(n.ems_ref, cg.ems_ref)
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
           when 'MiddlewareDeployment', 'MiddlewareServer' then entity.nativeid
           when 'Hawkular' then entity.id.to_s
         else entity.ems_ref
         end

    data = {:id => id, :name => entity.name, :status => status, :kind => kind, :miq_id => entity.id}
    data
  end

  def entity_status(entity, kind)
    'Unknown'
  end

  def build_link(source, target)
    {:source => source, :target => target}
  end

  def retrieve_providers
    if @provider_id
      providers = ManageIQ::Providers::MiddlewareManager.where(:id => @provider_id)
    else  # provider id is empty when the topology is generated for all the providers together
      providers = ManageIQ::Providers::MiddlewareManager.all
    end
    providers
  end

  def build_kinds
    kinds =  { :MiddlewareServer => true,
               :MiddlewareDeployment => true,
             }
    if @providers.any? { |instance| instance.kind_of?(ManageIQ::Providers::Hawkular::MiddlewareManager) }
      kinds.merge!(:Hawkular => true)
    end

    kinds
  end
end
