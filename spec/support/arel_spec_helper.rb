module ArelSpecHelper
  # stock to_sql is not supported by all arel nodes (noteably: attribute)
  # So this is needed to test the generated sql
  def stringify_arel(nodes, model = MiqReport)
    visitor = Arel::Visitors::ToSql.new model.connection
    Array.wrap(nodes).map { |node| visitor.accept(node, Arel::Collectors::SQLString.new).value }
  end
end
