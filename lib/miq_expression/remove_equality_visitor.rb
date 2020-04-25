class MiqExpression
  class RemoveEqualityCollector
    attr_reader :binds
    def initialize(node_to_remove, binds)
      @node_to_remove = node_to_remove
      @binds = binds
    end

    attr_reader :node_to_remove

    def next_bind_value
      @binds.shift
    end
  end
  # rubocop:disable Naming/MethodName
  class RemoveEqualityVisitor < Arel::Visitors::Reduce
    # @return [Arel::Node|nil] the replacement node from this grouping
    def visit_nil(object, _collector)
      object
    end

    # @return [Arel::Node|nil] the replacement node from this grouping
    def visit_Arel_Nodes_Equality(object, collector)
      field = collector.node_to_remove
      if (object.left == field.left && object.right == field.right) ||
         (object.right == field.left && object.left == field.right)
        # remove this node from the query
        nil
      elsif object.right.kind_of?(Arel::Nodes::BindParam)
        # replace this node with "field = $(next value from the binds array)"
        value = object.right
        value = collector.next_bind_value if !value.respond_to?(:value_for_database)
        object.left.eq(value.value_for_database)
      else
        # leave this node in the query unchanged
        object
      end
    end

    # @return [Arel::Node|nil] the replacement node from this grouping
    def visit_Arel_Nodes_And(object, collector)
      children = object.children.compact.flatten.map { |q| visit(q, collector) }
      children.compact!

      if children.blank?
        nil
      elsif children.size == 1
        children.first
      elsif children == object.children
        object
      else
        Arel::Nodes::And.new(children)
      end
    end

    # @return [Arel::Node|nil] the replacement node from this grouping
    def visit_Arel_Nodes_Grouping(object, collector)
      expr = visit(object.expr, collector)
      if expr == object.expr
        object
      elsif expr.nil?
        nil
      else
        Arel::Nodes::Grouping.new(expr)
      end
    end

    # This method does 2 things:
    # - remove node_to_remove from the query
    # - replace bind variables with static variables in the query
    #
    # collector is just a tuple of the node_to_remove and the bound_attributes that are passed in,
    #   and not a ActiveRecord/Arel construct.
    #
    # Active record has the concept of the bind param values, but arel does not.
    # So converting a query into arel will lose the values for the bind parameters.
    # The arel becomes incomplete and can not generate valid sql.
    #
    # This method takes the values from the query's bound_attributes and plugs them into the arel.
    # The arel once again can generate valid sql.
    #
    # @param query [Arel::Nodes::Node] a where clause (this will be mutated)
    # @param node_to_remove [Arel::Nodes::Equality] the clause to remove
    # @param bind [Array[ActiveModel::Attribute]] values to populate in the BindParam slots (this will be mutated)
    # @return [Arel::Nodes::Node|nil] query without the node_to_remove
    def self.accept(query, node_to_remove, binds = [])
      # TODO: use collector to receive nodes (vs returning the value)
      collector = RemoveEqualityCollector.new(node_to_remove, binds)
      new.accept(query, collector) unless query.nil?
    end
  end
  # rubocop:enable Naming/MethodName
end
