class MiddlewareTopologyService < TopologyService
  def initialize(provider_id)
    @provider_id = provider_id
    @providers = retrieve_providers(ManageIQ::Providers::MiddlewareManager, @provider_id)
  end

  def build_topology
    topology = {}
    topo_items = {}
    links = []

    @providers.each do |provider|
      topo_items[provider.id.to_s] = build_entity_data(provider)
      provider.middleware_servers.each do |n|
        topo_items[n.ems_ref] = build_entity_data(n)
        links << build_link(provider.id.to_s, n.ems_ref)
        n.middleware_deployments.each do |cg|
          topo_items[cg.ems_ref] = build_entity_data(cg)
          links << build_link(n.ems_ref, cg.ems_ref)
        end
      end
    end

    topology[:items] = topo_items
    topology[:relations] = links
    topology[:kinds] = build_kinds
    topology
  end

  def entity_display_type(entity)
    if entity.kind_of?(ManageIQ::Providers::MiddlewareManager)
      entity.class.short_token
    else
      entity.class.name.demodulize
    end
  end

  def build_entity_data(entity)
    data = build_base_entity_data(entity)
    data.merge!(:status => 'Unknown',
                :display_kind => entity_display_type(entity))
    data[:icon] = entity.decorate.try(:listicon_image)
    data.merge!(:id => entity_id(entity)) # temporarily overriding id set in build_base_entity_data
    data
  end

  def entity_id(entity) #temporarily overriding entity_id method in base topology service class
    if entity.kind_of?(ManageIQ::Providers::BaseManager) # any type of provider
      id = entity.id.to_s
    elsif entity.kind_of?(MiddlewareDeployment) || entity.kind_of?(MiddlewareServer)
      id = entity.nativeid
    else
      id = entity.ems_ref
    end
    id
  end

  def build_kinds
    kinds = [:MiddlewareServer, :MiddlewareDeployment, :MiddlewareManager]
    build_legend_kinds(kinds)
  end
end
