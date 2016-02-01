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
      topo_items[provider.id.to_s] = build_entity_data(provider, provider.type.split('::')[2])
      provider.middleware_servers.each do |n|
        topo_items[n.ems_ref] = build_entity_data(n, 'MiddlewareServer')
        links << build_link(provider.id.to_s, n.ems_ref)
        n.middleware_deployments.each do |cg|
          topo_items[cg.ems_ref] = build_entity_data(cg, 'MiddlewareDeployment')
          links << build_link(n.ems_ref, cg.ems_ref)
        end
      end
    end

    topology[:items] = topo_items
    topology[:relations] = links
    topology[:kinds] = build_kinds
  end

  def build_entity_data(entity, kind)
    status = entity_status(entity, kind)
    id = case kind
         when 'MiddlewareDeployment', 'MiddlewareServer' then entity.nativeid
         when 'Hawkular' then entity.id.to_s
         else entity.ems_ref
         end

    {:id => id, :name => entity.name, :status => status, :kind => kind, :miq_id => entity.id}
  end

  def entity_status(_entity, _kind)
    'Unknown'
  end

  def build_link(source, target)
    {:source => source, :target => target}
  end

  def retrieve_providers
    if @provider_id
      ManageIQ::Providers::MiddlewareManager.where(:id => @provider_id)
    else # provider id is empty when the topology is generated for all the providers together
      ManageIQ::Providers::MiddlewareManager.all
    end
  end

  def build_kinds
    [:MiddlewareServer, :MiddlewareDeployment].each_with_object({}) { |kind, h| h[kind] = true }
    if @providers.any? { |instance| instance.kind_of?(ManageIQ::Providers::Hawkular::MiddlewareManager) }
      kinds.merge!(:Hawkular => true)
    end

    kinds
  end
end
