module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module SchemaStatements
        def columns_for_distinct(columns, orders) #:nodoc:
          order_columns = orders.reject(&:blank?).map { |s|
              # Convert Arel node to string
              s = s.to_sql unless s.is_a?(String)
              # Remove any ASC/DESC modifiers
              s.gsub(/\s+(?:ASC|DESC)\b/i, "")
               .gsub(/\s+NULLS\s+(?:FIRST|LAST)\b/i, "")
            }.reject(&:blank?).map.with_index { |column, i| "#{column} AS alias_#{i}" }

          (order_columns << super).join(", ")
        end
      end
    end
  end
end
