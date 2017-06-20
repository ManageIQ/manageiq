class MiqExpression
  class WhereExtractionVisitor < Arel::Visitors::PostgreSQL
    def visit_Arel_Nodes_SelectStatement(o, collector)
      collector = o.cores.inject(collector) do |c, x|
        visit_Arel_Nodes_SelectCore(x, c)
      end
    end

    def visit_Arel_Nodes_SelectCore(o, collector)
      unless o.wheres.empty?
        len = o.wheres.length - 1
        o.wheres.each_with_index do |x, i|
          collector = visit(x, collector)
          collector << AND unless len == i
        end
      end

      collector
    end
  end
end
