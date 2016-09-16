module Spec
  module Support
    module ArelHelper
      # stock to_sql is not supported by all arel nodes (noteably: attribute)
      # So this is needed to test the generated sql
      def stringify_arel(nodes, model = MiqReport)
        visitor = Arel::Visitors::ToSql.new model.connection
        Array.wrap(nodes).map { |node| visitor.accept(node, Arel::Collectors::SQLString.new).value }
      end

      # run the sql for a virtual column. making sure it works in select and order
      def virtual_column_sql_value(klass, v_col_name)
        query = klass.select(:id, klass.arel_attribute(v_col_name.to_sym).as("extra"))
                     .order(v_col_name.to_sym)
        query.first["extra"]
      end
    end
  end
end
