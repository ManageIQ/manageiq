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
    end
  end
end
