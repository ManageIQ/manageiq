module ManagerRefresh::SaveCollection
  module Saver
    module SqlHelper
      # TODO(lsmola) all below methods should be rewritten to arel, but we need to first extend arel to be able to do
      # this

      extend ActiveSupport::Concern

      included do
        include SqlHelperUpsert
        include SqlHelperUpdate
      end

      # Returns quoted column name
      # @param key [Symbol] key that is column name
      # @returns [String] quoted column name
      def quote_column_name(key)
        get_connection.quote_column_name(key)
      end

      # @return [ActiveRecord::ConnectionAdapters::AbstractAdapter] ActiveRecord connection
      def get_connection
        ActiveRecord::Base.connection
      end

      # Builds a multiselection conditions like (table1.a = a1 AND table2.b = b1) OR (table1.a = a2 AND table2.b = b2)
      #
      # @param hashes [Array<Hash>] data we want to use for the query
      # @return [String] condition usable in .where of an ActiveRecord relation
      def build_multi_selection_query(hashes)
        inventory_collection.build_multi_selection_condition(hashes, unique_index_columns)
      end

      # Quotes a value. For update query, the value also needs to be explicitly casted, which we can do by
      # type_cast_for_pg param set to true.
      #
      # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter] ActiveRecord connection
      # @param value [Object] value we want to quote
      # @param name [Symbol] name of the column
      # @param type_cast_for_pg [Boolean] true if we want to also cast the quoted value
      # @return [String] quoted and based on type_cast_for_pg param also casted value
      def quote(connection, value, name = nil, type_cast_for_pg = nil)
        # TODO(lsmola) needed only because UPDATE FROM VALUES needs a specific PG typecasting, remove when fixed in PG
        if type_cast_for_pg
          quote_and_pg_type_cast(connection, value, name)
        else
          connection.quote(value)
        end
      rescue TypeError => e
        _log.error("Can't quote value: #{value}, of :#{name} and #{inventory_collection}")
        raise e
      end

      # Quotes and type casts the value.
      #
      # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter] ActiveRecord connection
      # @param value [Object] value we want to quote
      # @param name [Symbol] name of the column
      # @return [String] quoted and casted value
      def quote_and_pg_type_cast(connection, value, name)
        pg_type_cast(
          connection.quote(value),
          pg_types[name]
        )
      end

      # Returns a type casted value in format needed by PostgreSQL
      #
      # @param value [Object] value we want to quote
      # @param sql_type [String] PostgreSQL column type
      # @return [String] type casted value in format needed by PostgreSQL
      def pg_type_cast(value, sql_type)
        if sql_type.nil?
          value
        else
          "#{value}::#{sql_type}"
        end
      end

      # Effective way of doing multiselect
      #
      # If we use "(col1, col2) IN [(a,e), (b,f), (b,e)]" it's not great, just with 10k batch, we see
      # *** ActiveRecord::StatementInvalid Exception: PG::StatementTooComplex: ERROR:  stack depth limit exceeded
      # HINT:  Increase the configuration parameter "max_stack_depth" (currently 2048kB), after ensuring the
      # platform's stack depth limit is adequate.
      #
      # If we use "(col1 = a AND col2 = e) OR (col1 = b AND col2 = f) OR (col1 = b AND col2 = e)" with 10k batch, it
      # takes about 6s and consumes 300MB, with 100k it takes ~1h and consume 3GB in Postgre process
      #
      # The best way seems to be using CTE, where the list of values we want to map is turned to 'table' and we just
      # do RIGHT OUTER JOIN to get the complement of given identifiers. Tested on getting complement of 100k items,
      # using 2 cols (:ems_ref and :uid_ems) from total 150k rows. It takes ~1s and 350MB in Postgre process
      #
      # @param manager_uuids [Array<String>, Array[Hash]] Array with manager_uuids of entities. The keys have to match
      #        inventory_collection.manager_ref. We allow passing just array of strings, if manager_ref.size ==1, to
      #        spare some memory
      # @return [Arel::SelectManager] Arel for getting complement of uuids. This method modifies the passed
      #         manager_uuids to spare some memory
      def complement_of!(manager_uuids)
        # manager_uuids = inventory_collection.full_collection_for_comparison.select(:id, :ems_ref, :uid_ems).limit(100000).to_a.map {|x| {"ems_ref" => x.ems_ref, "uid_ems" => x.uid_ems} }

        connection = ActiveRecord::Base.connection
        all_attribute_keys = inventory_collection.manager_ref
        all_attribute_keys_array = inventory_collection.manager_ref.map(&:to_s)
        all_attribute_keys_array_q = all_attribute_keys_array.map { |x| quote_column_name(x) }

        # For Postgre, only first set of values should contain the type casts
        first_value = manager_uuids.shift.to_h
        first_value = "(#{all_attribute_keys_array.map { |x| quote(connection, first_value[x], x, true) }.join(",")})"

        # Rest of the values, without the type cast
        values = manager_uuids.map! do |hash|
          "(#{all_attribute_keys_array.map { |x| quote(connection, hash[x], x, false) }.join(",")})"
        end.join(",")

        values = [first_value, values].join(",")
        active_entities_query = <<-SQL
          SELECT  *
          FROM    (VALUES #{values}) AS active_entities_table(#{all_attribute_keys_array_q.join(",")})
        SQL

        active_entities     = Arel::Table.new(:active_entities)
        active_entities_cte = Arel::Nodes::As.new(active_entities, Arel.sql("(#{active_entities_query})"))
        all_entities     = Arel::Table.new(:all_entities)
        all_entities_cte = Arel::Nodes::As.new(
          all_entities,
          Arel.sql("(#{inventory_collection.full_collection_for_comparison.select(:id, *all_attribute_keys_array).to_sql})")
        )

        join_condition = all_attribute_keys.map { |key| active_entities[key].eq(all_entities[key]) }.inject(:and)
        where_condition = all_attribute_keys.map { |key| active_entities[key].eq(nil) }.inject(:and)

        active_entities
          .project(all_entities[:id])
          .join(all_entities, Arel::Nodes::RightOuterJoin)
          .on(join_condition)
          .with(active_entities_cte, all_entities_cte)
          .where(where_condition)
      end
    end
  end
end
