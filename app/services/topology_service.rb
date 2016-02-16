class TopologyService
  def retrieve_providers(provider_id, provider_type)
    if provider_id
      provider_type.where(:id => provider_id)
    else  # provider id is empty when the topology is generated for all the providers together
      provider_type.all
    end
  end

  def build_link(source, target)
    {:source => source, :target => target}
  end

  def entity_type(entity)
    entity.class.name.demodulize
  end

  def build_legend_kinds(kinds)
    kinds.each_with_object({}) { |kind, h| h[kind] = true }
  end

  def entity_id(entity)
    entity_type(entity) + entity.compressed_id.to_s
  end

  def build_base_entity_data(entity)
    {:name   => entity.name,
     :kind   => entity_type(entity),
     :miq_id => entity.id}
  end
end
