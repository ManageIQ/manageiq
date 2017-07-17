module ManagerRefresh::SaveCollection
  module Saver
    module SqlHelper
      # TODO(lsmola) all below methods should be rewritten to arel, but we need to first extend arel to be able to do
      # this
      def build_insert_set_cols(key)
        "#{quote_column_name(key)} = EXCLUDED.#{quote_column_name(key)}"
      end

      def build_insert_query(inventory_collection, all_attribute_keys, hashes)
        all_attribute_keys_array = all_attribute_keys.to_a
        table_name               = inventory_collection.model_class.table_name
        values                   = hashes.map do |hash|
          "(#{all_attribute_keys_array.map { |x| ActiveRecord::Base.connection.quote(hash[x]) }.join(",")})"
        end.join(",")
        col_names = all_attribute_keys_array.map { |x| quote_column_name(x) }.join(",")

        insert_query = %{
          INSERT INTO #{table_name} (#{col_names})
            VALUES
              #{values}
          ON CONFLICT (#{inventory_collection.unique_index_columns.map { |x| quote_column_name(x) }.join(",")})
            DO
              UPDATE
                SET #{all_attribute_keys_array.map { |key| build_insert_set_cols(key) }.join(", ")}
        }

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

        if inventory_collection.dependees.present?
          insert_query += %{
            RETURNING id,#{inventory_collection.unique_index_columns.map { |x| quote_column_name(x) }.join(",")}
          }
        end

        insert_query
      end

      def build_update_set_cols(key)
        "#{quote_column_name(key)} = updated_values.#{quote_column_name(key)}"
      end

      def quote_column_name(key)
        ActiveRecord::Base.connection.quote_column_name(key)
      end

      def build_update_query(inventory_collection, all_attribute_keys, hashes)
        all_attribute_keys_array = all_attribute_keys.to_a.delete_if { |x| %i(type).include?(x) }
        table_name               = inventory_collection.model_class.table_name
        values = hashes.map do |hash|
          "(#{all_attribute_keys_array.map { |x| quote(hash[x], x, inventory_collection) }.join(",")})"
        end.join(",")

        where_cond = inventory_collection.unique_index_columns.map do |x|
          "updated_values.#{quote_column_name(x)} = #{table_name}.#{quote_column_name(x)}"
        end.join(" AND ")

        update_query = %{
          UPDATE #{table_name}
            SET
              #{all_attribute_keys_array.map { |key| build_update_set_cols(key) }.join(",")}
          FROM (
            VALUES
              #{values}
          ) AS updated_values (#{all_attribute_keys_array.map { |x| quote_column_name(x) }.join(",")})
          WHERE #{where_cond}
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

      def build_multi_selection_query(inventory_collection, hashes)
        inventory_collection.build_multi_selection_condition(hashes, inventory_collection.unique_index_columns)
      end

      def quote(value, name = nil, inventory_collection = nil)
        # TODO(lsmola) needed only because UPDATE FROM VALUES needs a specific PG typecasting, remove when fixed in PG
        name.nil? ? ActiveRecord::Base.connection.quote(value) : quote_and_pg_type_cast(value, name, inventory_collection)
      end

      def quote_and_pg_type_cast(value, name, inventory_collection)
        pg_type_cast(
          ActiveRecord::Base.connection.quote(value),
          inventory_collection.model_class.columns_hash[name.to_s].type
        )
      end

      def pg_type_cast(value, type)
        case type
        when :string, :text        then value
        when :integer              then value
        when :float                then value
        when :decimal              then value
        when :datetime, :timestamp then "#{value}::timestamp"
        when :time                 then "#{value}::time"
        when :date                 then "#{value}::date"
        when :binary               then "#{value}::binary"
        when :boolean              then "#{value}::boolean"
        else value
        end
      end
    end
  end
end
