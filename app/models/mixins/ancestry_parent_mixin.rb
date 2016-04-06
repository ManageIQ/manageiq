# Ancestry, but using a parent_id
module AncestryParentMixin
  def self.included(base)
    base.extend(AncestryParentMixin::ARClassMethods)
  end

  module ARClassMethods
    def acts_as_recursive_tree(options = {})
      include AncestryParentMixin::InstanceMethods
      extend AncestryParentMixin::ClassMethods

      cattr_accessor :ancestry_parent_column
      self.ancestry_parent_column = options[:parent_id] || :parent_id

      # Save self as base class (for STI)
      cattr_accessor :ancestry_base_class
      self.ancestry_base_class = self
    end
  end

  module ClassMethods
    def get_ancestry_parent_column
      ancestry_base_class.ancestry_parent_column
    end

    def subtree_conditions(instance_id)
      instance_id = instance_id.send(primary_key) if instance_id.respond_to?(primary_key)
      ancestry_id_sql(arel_table[primary_key].eq(instance_id))
    end

    def descendant_conditions(instance_id)
      instance_id = instance_id.send(primary_key) if instance_id.respond_to?(primary_key)
      ancestry_id_sql(arel_table[get_ancestry_parent_column].eq(instance_id))
    end

    def ancestry_objects(clause)
      where("id IN (#{ancestry_id_sql(clause)})")
    end

    def root_nodes
      ancestry_objects(arel_table[get_ancestry_parent_column].eq(nil))
    end

    # this can be used with a JOIN or IN clause, both query plans look similar
    def ancestry_id_sql(clause)
      clause = clause.to_sql if clause.respond_to?(:to_sql)
      <<-SQL
        WITH RECURSIVE search_tree(id, path) AS (
            SELECT #{primary_key}, ARRAY[id]
            FROM #{table_name}
            WHERE #{clause}
          UNION ALL
            SELECT #{table_name}.#{primary_key}, path || #{table_name}.#{primary_key}
            FROM search_tree
            JOIN #{table_name} ON #{table_name}.#{get_ancestry_parent_column} = search_tree.#{primary_key}
            WHERE NOT #{table_name}.#{primary_key} = ANY(path)
        )
        SELECT #{primary_key} FROM search_tree
      SQL
      # #{"ORDER BY path" if order}
    end

    def arrange_nodes(nodes)
      index, root_id = index_nodes(nodes)
      index[root_id]
    end

    # @param nodes [Array<Object>]
    # @return [Array<Hash<Nil|Numeric,Array<Object>],(Nul,Numeric)]
    # index is keyed off of node id, and it links to all children
    #
    # to view all root objects, index[root_id].keys
    def index_nodes(nodes)
      index = Hash.new { |h, k| h[k] = ActiveSupport::OrderedHash.new }
      parent_ids = Hash.new

      nodes.each do |node|
        index[node.send(get_ancestry_parent_column)][node] = index[node.id]
        parent_ids[node.id] = node.send(get_ancestry_parent_column)
      end

      return [{}, nil] if parent_ids.empty?

      # pick a random id, traverse up until hit top level
      # NOTE: root_id of nil is possibly valid
      root_id = parent_ids.first.first
      while root_id && (index[possible_id = parent_ids[root_id]]).present?
        root_id = possible_id
      end
      [index, root_id]
    end
  end

  module InstanceMethods
    def ancestors
      result = []
      node = self

      while (node = node.parent)
        result << node
      end

      result
    end

    def subtree
      self.class.where("id IN (#{self.class.subtree_conditions(self)})")
    end

    def descendants
      self.class.where("id IN (#{self.class.descendant_conditions(self)})")
    end
  end
end
