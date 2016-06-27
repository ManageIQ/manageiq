class MiddlewareTopologyService < TopologyService
  include UiServiceMixin

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
          :MiddlewareDeployments => nil,
          :MiddlewareDatasources => nil
        }}}

    preloaded = @providers.includes(:middleware_server => [:middleware_deployment, :middleware_datasource])

    preloaded.each do |entity|
      topo_items, links = build_recursive_topology(entity, entity_relationships[:MiddlewareManager], topo_items, links)
    end

    populate_topology(topo_items, links, build_kinds, icons)
  end

  def entity_display_type(entity)
    if entity.kind_of?(ManageIQ::Providers::MiddlewareManager)
      entity.class.short_token
    elsif entity.kind_of?(MiddlewareDeployment)
      suffix = if entity.name.end_with? '.ear'
                 'Ear'
               elsif entity.name.end_with? '.war'
                 'War'
               else
                 ''
               end
      entity.class.name.demodulize + suffix
    else
      entity.class.name.demodulize
    end
  end

  def build_entity_data(entity)
    data = build_base_entity_data(entity)
    data[:status] = 'Unknown'
    data[:display_kind] = entity_display_type(entity)
    data[:icon] = entity.decorate.try(:item_image) unless glyph? entity
    data
  end

  def glyph?(entity)
    [MiddlewareDatasource, MiddlewareDeployment].any? { |klass| entity.kind_of? klass }
  end

  def build_kinds
    kinds = [:MiddlewareServer, :MiddlewareDeployment, :MiddlewareDatasource, :MiddlewareManager]
    build_legend_kinds(kinds)
  end
end
