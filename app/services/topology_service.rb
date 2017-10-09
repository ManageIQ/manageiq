class TopologyService
  class << self
    attr_reader :provider_class
  end

  def initialize(provider_id)
    @providers = retrieve_providers(provider_id)
  end

  def retrieve_providers(provider_id = nil)
    if provider_id
      retrieve_entity(provider_id)
    else  # provider id is empty when the topology is generated for all the providers together
      self.class.provider_class.all
    end
  end

  def retrieve_entity(entity_id)
    self.class.provider_class.where(:id => entity_id)
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
    {
      :name   => entity.name,
      :kind   => entity_type(entity),
      :model  => entity.class.to_s,
      :miq_id => entity.id,
      :key    => entity_id(entity)
    }
  end

  def populate_topology(topo_items, links, kinds, icons)
    {:items     => topo_items,
     :relations => links,
     :kinds     => kinds,
     :icons     => icons
    }
  end

  def group_nodes_by_model(nodes)
    return unless block_given?
    nodes_grouped_by_model = nodes.group_by { |_, v| v[:model] }

    nodes_grouped_by_model.each do |klass, entity_data|
      yield(klass, entity_data.map { |x| [x.second[:miq_id], x.second[:key]] }.to_h)
    end
  end

  def build_recursive_topology(entity, entity_relationships_mapping, topo_items, links)
    unless entity.nil?
      topo_items[entity_id(entity)] = build_entity_data(entity)
      unless entity_relationships_mapping.nil?
        entity_relationships_mapping.keys.each do |rel_name|
          relations = entity.send(rel_name.to_s.underscore.downcase)
          if relations.kind_of?(ActiveRecord::Associations::CollectionProxy)
            relations.each do |relation|
              build_rel_data_and_links(entity, entity_relationships_mapping, rel_name, links, relation, topo_items)
            end
          else
            # single relation such as has_one or belongs_to, can't iterate with '.each'
            build_rel_data_and_links(entity, entity_relationships_mapping, rel_name, links, relations, topo_items)
          end
        end
      end

      remove_list = []
      group_nodes_by_model(topo_items) do |klass, node_of_resource| # node is hash { 10001 => 'CloudNetwork1r0001'}
        node_resource_ids = node_of_resource.keys
        remove_ids = node_resource_ids - Rbac::Filterer.filtered(klass.safe_constantize.where(:id => node_resource_ids)).map(&:id)
        remove_list << remove_ids.map { |x| node_of_resource[x] } if remove_ids.present?
      end

      # remove nodes and edges
      remove_list.flatten.each do |x|
        topo_items.delete(x)
        links = links.select do |edge|
          !(edge[:source] == x || edge[:target] == x)
        end
      end
    end

    [topo_items, links]
  end

  def build_rel_data_and_links(entity, entity_relationships, key, links, relation, topo_items)
    unless relation.nil?
      topo_items[entity_id(relation)] = build_entity_data(relation)
      links << build_link(entity_id(entity), entity_id(relation))
    end
    build_recursive_topology(relation, entity_relationships[key], topo_items, links)
  end

  def build_entity_relationships(included_relations)
    hash = {}
    case included_relations
      when Hash
        included_relations.each_pair do |key, hash_value|
          hash_value = build_entity_relationships(hash_value)
          hash[key.to_s.camelize.to_sym] = hash_value
        end
      when Array
        included_relations.each do |array_value|
          hash.merge!(build_entity_relationships(array_value))
        end
      when Symbol
        hash[included_relations.to_s.camelize.to_sym] = nil
    end
    hash
  end
end
