class MiqExpression
  class QueryHelper
    # This method does 2 things:
    # - remove node from the query
    # - replace bind variables in the query
    #
    # Active record has the concept of the bind param values, but arel does not.
    # So converting a query into arel will loose the values for the bind parameters.
    # The arel becomes incomplete and can not generate valid sql.
    #
    # This method takes the values from they query's bound_attributes and plugs them into the arel.
    # The arel once again can generate valid sql.
    #
    # @param query [Arel::Nodes::Node] a where clause
    # @param node_to_remove [Arel::Nodes::Equality] the clause to remove
    # @param bind [Array[ActiveModel::Attribute]] values to populate in the BindParam slots.
    # @return query without the node_to_remove
    def self.remove_node(query, node_to_remove, binds = [])
      traverse_and_replace(query) do |q|
        if (q.left == node_to_remove.left && q.right == node_to_remove.right) ||
          (q.right == node_to_remove.left && q.left == node_to_remove.right)
          # remove this node from the query
          nil
         elsif q.right.kind_of?(Arel::Nodes::BindParam)
          # replace this node with "field = $(next value from the binds array)"
          value = object.right.respond_to?(:value) ? object.right.value.value : collector.next_bind_value.value_for_database
          q.left.eq(value)
        else
          # leave this node in the query unchanged
          q
        end
      end
    end

    def self.traverse_and_replace(query, &bind)
      return if query.nil?

      if query.kind_of?(Arel::Nodes::And)
        children = query.children.compact.flatten.map { |q| traverse_and_replace(q, &bind) }
        children.compact!

        if children.empty?
          nil
        elsif children.size == 1
          children.first
        else
          query.class.new(children)
        end
      elsif query.kind_of?(Arel::Nodes::Grouping)
        q2 = traverse_and_replace(query.expr, &bind)
        q2 ? query.class.new(q2) : q2
      elsif query.kind_of?(Arel::Nodes::Equality)
        yield(query)
      else
        query
      end
    end
  end
end
