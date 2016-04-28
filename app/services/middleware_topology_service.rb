class MiddlewareTopologyService < TopologyService
  def initialize(provider_id)
    @provider_id = provider_id
    @providers = retrieve_providers(ManageIQ::Providers::MiddlewareManager, @provider_id)
  end

  def build_topology
    topo_items = {}
    links = []

    entity_relationships = {
      :MiddlewareManager => {
        :MiddlewareServers => {
          :MiddlewareDeployments => nil
        }}}

    preloaded = @providers.includes(:middleware_server => [:middleware_deployment])

    preloaded.each do |entity|
      topo_items, links = build_recursive_topology(entity, entity_relationships[:MiddlewareManager], topo_items, links)
    end

    populate_topology(topo_items, links, build_kinds, {})
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
    data
  end

  def build_kinds
    kinds = [:MiddlewareServer, :MiddlewareDeployment, :MiddlewareManager]
    build_legend_kinds(kinds)
  end
end
