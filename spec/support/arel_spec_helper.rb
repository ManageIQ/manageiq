module ArelSpecHelper
  # stock to_sql is not supported by all arel nodes (noteably: attribute)
  # So this is needed to test the generated sql
  def stringify_arel(nodes, model = MiqReport)
    visitor = Arel::Visitors::ToSql.new model.connection
    Array.wrap(nodes).map { |node| visitor.accept(node, Arel::Collectors::SQLString.new).value }
  end

  # run the sql for a virtual column. making sure it works in select and order
  # due to active record, this test uses inner joins
  def virtual_column_sql_value(klass, v_col_name)
    query = klass.select(klass.arel_attribute("id"),
                         Arel::Nodes::As.new(klass.arel_attribute(v_col_name),
                                             Arel::Nodes::SqlLiteral.new("extra")))
                 .joins(klass.virtual_includes(v_col_name).presence || [])
                 .order(klass.arel_attribute(v_col_name))
    query.first["extra"]
  end
end
