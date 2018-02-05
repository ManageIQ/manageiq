module ManagerRefresh::SaveCollection
  module Saver
    module SqlHelper
      def on_conflict_update
        true
      end

      # TODO(lsmola) all below methods should be rewritten to arel, but we need to first extend arel to be able to do
      # this
      def build_insert_set_cols(key)
        "#{quote_column_name(key)} = EXCLUDED.#{quote_column_name(key)}"
      end

      def build_insert_query(all_attribute_keys, hashes)
        # Cache the connection for the batch
        connection = get_connection

        # Make sure we don't send a primary_key for INSERT in any form, it could break PG sequencer
        all_attribute_keys_array = all_attribute_keys.to_a - [primary_key.to_s, primary_key.to_sym]
        values                   = hashes.map do |hash|
          "(#{all_attribute_keys_array.map { |x| quote(connection, hash[x], x) }.join(",")})"
        end.join(",")
        col_names = all_attribute_keys_array.map { |x| quote_column_name(x) }.join(",")

        insert_query = %{
          INSERT INTO #{table_name} (#{col_names})
            VALUES
              #{values}
        }

        if on_conflict_update
          insert_query += %{
            ON CONFLICT (#{unique_index_columns.map { |x| quote_column_name(x) }.join(",")})
              DO
                UPDATE
                  SET #{all_attribute_keys_array.map { |key| build_insert_set_cols(key) }.join(", ")}
          }
        end

        # TODO(lsmola) do we want to exclude the ems_id from the UPDATE clause? Otherwise it might be difficult to change
        # the ems_id as a cross manager migration, since ems_id should be there as part of the insert. The attempt of
        # changing ems_id could lead to putting it back by a refresh.
        # TODO(lsmola) should we add :deleted => false to the update clause? That should handle a reconnect, without a
        # a need to list :deleted anywhere in the parser. We just need to check that a model has the :deleted attribute

        # This conditional will avoid rewriting new data by old data. But we want it only when remote_data_timestamp is a
        # part of the data, since for the fake records, we just want to update ems_ref.
        if supports_remote_data_timestamp?(all_attribute_keys)
          insert_query += %{
            WHERE EXCLUDED.remote_data_timestamp IS NULL OR (EXCLUDED.remote_data_timestamp > #{table_name}.remote_data_timestamp)
          }
        end

        insert_query += %{
          RETURNING "id",#{unique_index_columns.map { |x| quote_column_name(x) }.join(",")}
        }

        insert_query
      end

      def build_update_set_cols(key)
        "#{quote_column_name(key)} = updated_values.#{quote_column_name(key)}"
      end

      def quote_column_name(key)
        get_connection.quote_column_name(key)
      end

      def get_connection
        ActiveRecord::Base.connection
      end

      def build_update_query(all_attribute_keys, hashes)
        # Cache the connection for the batch
        connection = get_connection

        # We want to ignore type and create timestamps when updating
        all_attribute_keys_array = all_attribute_keys.to_a.delete_if { |x| %i(type created_at created_on).include?(x) }
        all_attribute_keys_array << :id

        values = hashes.map! do |hash|
          "(#{all_attribute_keys_array.map { |x| quote(connection, hash[x], x, true) }.join(",")})"
        end.join(",")

        update_query = %{
          UPDATE #{table_name}
            SET
              #{all_attribute_keys_array.map { |key| build_update_set_cols(key) }.join(",")}
          FROM (
            VALUES
              #{values}
          ) AS updated_values (#{all_attribute_keys_array.map { |x| quote_column_name(x) }.join(",")})
          WHERE updated_values.id = #{table_name}.id
        }

        # TODO(lsmola) do we want to exclude the ems_id from the UPDATE clause? Otherwise it might be difficult to change
        # the ems_id as a cross manager migration, since ems_id should be there as part of the insert. The attempt of
        # changing ems_id could lead to putting it back by a refresh.

        # This conditional will avoid rewriting new data by old data. But we want it only when remote_data_timestamp is a
        # part of the data, since for the fake records, we just want to update ems_ref.
        if supports_remote_data_timestamp?(all_attribute_keys)
          update_query += %{
            AND (updated_values.remote_data_timestamp IS NULL OR (updated_values.remote_data_timestamp > #{table_name}.remote_data_timestamp))
          }
        end
        update_query
      end

      def build_multi_selection_query(hashes)
        inventory_collection.build_multi_selection_condition(hashes, unique_index_columns)
      end

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

      def quote_and_pg_type_cast(connection, value, name)
        pg_type_cast(
          connection.quote(value),
          pg_types[name]
        )
      end

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
