module ManagerRefresh::SaveCollection
  module Saver
    module SqlHelperUpdate
      # Builds update clause for one column identified by the passed key
      #
      # @param key [Symbol] key that is column name
      # @return [String] SQL clause for updating one column
      def build_update_set_cols(key)
        "#{quote_column_name(key)} = updated_values.#{quote_column_name(key)}"
      end

      # Build batch update query
      #
      # @param all_attribute_keys [Array<Symbol>] Array of all columns we will be saving into each table row
      # @param hashes [Array<Hash>] data used for building a batch update sql query
      def build_update_query(all_attribute_keys, hashes)
        _log.debug("Building update query for #{inventory_collection} of size #{inventory_collection.size}...")
        # Cache the connection for the batch
        connection = get_connection

        # We want to ignore create timestamps when updating
        all_attribute_keys_array = all_attribute_keys.to_a.delete_if { |x| %i(created_at created_on).include?(x) }
        all_attribute_keys_array << :id

        update_query = update_query_beginning(all_attribute_keys_array)
        update_query += update_query_reset_version_columns(all_attribute_keys)
        update_query += update_query_from_values(hashes, all_attribute_keys_array, connection)
        update_query += update_query_version_conditions(all_attribute_keys)
        update_query += update_query_returning

        _log.debug("Building update query for #{inventory_collection} of size #{inventory_collection.size}...Complete")

        update_query
      end

      private

      def update_query_beginning(all_attribute_keys_array)
        <<-SQL
          UPDATE #{table_name}
            SET
              #{all_attribute_keys_array.map { |key| build_update_set_cols(key) }.join(",")}
        SQL
      end

      def update_query_reset_version_columns(all_attribute_keys)
        if supports_remote_data_timestamp?(all_attribute_keys)
          # Full row update will reset the partial update timestamps
          <<-SQL
            , resource_timestamps = '{}', resource_timestamps_max = NULL
          SQL
        elsif supports_remote_data_version?(all_attribute_keys)
          <<-SQL
            , resource_versions = '{}', resource_versions_max = NULL
          SQL
        else
          ""
        end
      end

      def update_query_from_values(hashes, all_attribute_keys_array, connection)
        values = hashes.map! do |hash|
          "(#{all_attribute_keys_array.map { |x| quote(connection, hash[x], x, true) }.join(",")})"
        end.join(",")

        <<-SQL
          FROM (
            VALUES
              #{values}
          ) AS updated_values (#{all_attribute_keys_array.map { |x| quote_column_name(x) }.join(",")})
          WHERE updated_values.id = #{table_name}.id
        SQL
      end

      def update_query_version_conditions(all_attribute_keys)
        # This conditional will avoid rewriting new data by old data. But we want it only when remote_data_timestamp is
        # a part of the data, since for the fake records, we just want to update ems_ref.
        if supports_remote_data_timestamp?(all_attribute_keys)
          <<-SQL
            AND (
              updated_values.resource_timestamp IS NULL OR (
                (#{table_name}.resource_timestamp IS NULL OR updated_values.resource_timestamp > #{table_name}.resource_timestamp) AND
                (#{table_name}.resource_timestamps_max IS NULL OR updated_values.resource_timestamp >= #{table_name}.resource_timestamps_max)
              )
            )
          SQL
        elsif supports_remote_data_version?(all_attribute_keys)
          <<-SQL
            AND (
              updated_values.resource_version IS NULL OR (
                (#{table_name}.resource_version IS NULL OR updated_values.resource_version > #{table_name}.resource_version) AND
                (#{table_name}.resource_versions_max IS NULL OR updated_values.resource_version >= #{table_name}.resource_versions_max)
              )
            )
          SQL
        else
          ""
        end
      end

      def update_query_returning
        if inventory_collection.parallel_safe?
          <<-SQL
            RETURNING updated_values.#{quote_column_name("id")}, #{unique_index_columns.map { |x| "updated_values.#{quote_column_name(x)}" }.join(",")}
          SQL
        else
          ""
        end
      end
    end
  end
end
