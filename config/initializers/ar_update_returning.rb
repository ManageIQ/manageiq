if ActiveRecord::VERSION::STRING >= "7.0.0"
  raise "Monkey patch only works with rails 6.1 - talk to kbrock"
end

module ActiveRecord
  class Relation
    def update_with_results(updates)
      # copy/paste rails 6.1 relation.rb#update_all
      # rubocop:disable Style/ClassCheck
      # rubocop:disable Layout/MultilineOperationIndentation
      # rubocop:disable Style/MethodCallWithArgsParentheses
      raise ArgumentError, "Empty list of attributes to change" if updates.blank?

      arel = eager_loading? ? apply_join_dependency.arel : build_arel
      arel.source.left = table

      stmt = Arel::UpdateManager.new
      stmt.table(arel.source)
      stmt.key = table[primary_key]
      stmt.take(arel.limit)
      stmt.offset(arel.offset)
      stmt.order(*arel.orders)
      stmt.wheres = arel.constraints

      if updates.is_a?(Hash)
        if klass.locking_enabled? && # yes: "lock_version"
            !updates.key?(klass.locking_column) &&
            !updates.key?(klass.locking_column.to_sym)
          attr = table[klass.locking_column]
          updates[attr.name] = _increment_attribute(attr)
        end
        stmt.set _substitute_values(updates)
      else
        stmt.set Arel.sql(klass.sanitize_sql_for_assignment(updates, table.name))
      end
      # rubocop:enable Style/ClassCheck
      # rubocop:enable Layout/MultilineOperationIndentation
      # rubocop:enable Style/MethodCallWithArgsParentheses

      # REMOVED:
      # klass.connection.update(stmt, "#{klass} Update All", []).tap { reset }
      # ADDED:
      sql, binds = klass.connection.send(:to_sql_and_binds, stmt)
      # TODO: support select_values
      sql += " RETURNING #{klass.connection.quote_column_name(table_name)}.*"
      find_by_sql(sql, binds).tap { reset }
      # /CHANGE
    end
  end
end
