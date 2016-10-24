class InfraTopologyService < TopologyService
  include UiServiceMixin

  @provider_class = ManageIQ::Providers::InfraManager

  def entity_type(entity)
    entity.class.name.demodulize
  end

  def build_topology
    topo_items = {}
    links = []

    included_relations = [
      :tags,
      :ems_clusters => [
        :tags,
        :hosts,
      ],
    ]

    entity_relationships = {:InfraManager => build_entity_relationships(included_relations)}
    preloaded = @providers.includes(included_relations)

    preloaded.each do |entity|
      topo_items, links = build_recursive_topology(entity, entity_relationships[:InfraManager], topo_items, links)
    end

    populate_topology(topo_items, links, build_kinds, icons)
  end

  def entity_display_type(entity)
    if entity.kind_of?(ManageIQ::Providers::InfraManager)
      entity.class.short_token
    else
      name = entity.class.name.demodulize
      if entity.kind_of?(Vm)
        name.upcase # turn Vm to VM because it's an abbreviation
      else
        name
      end
    end
  end

  def build_entity_data(entity)
    data = build_base_entity_data(entity)
    data[:status]       = entity_status(entity)
    data[:display_kind] = entity_display_type(entity)

    if entity.try(:ems_id)
      data[:provider] = entity.ext_management_system.name
    end

    data
  end

  def entity_status(entity)
    case entity
    when ManageIQ::Providers::InfraManager
      entity.authentications.blank? ? 'Unknown' : entity.authentications.first.status.try(:capitalize)
    when Host
      entity.state ? entity.state.downcase.capitalize : 'Unknown'
    else
      'Unknown'
    end
  end

  def build_kinds
    kinds = [:InfraManager, :EmsCluster, :Host]
    build_legend_kinds(kinds)
  end
end
