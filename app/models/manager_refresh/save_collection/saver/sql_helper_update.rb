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

        # If there is not version attribute, the version conditions will be ignored
        version_attribute = if inventory_collection.parallel_safe? && supports_remote_data_timestamp?(all_attribute_keys)
                              :resource_timestamp
                            elsif inventory_collection.parallel_safe? && supports_remote_data_version?(all_attribute_keys)
                              :resource_version
                            end

        update_query = update_query_beginning(all_attribute_keys_array)
        update_query += update_query_reset_version_columns(version_attribute)
        update_query += update_query_from_values(hashes, all_attribute_keys_array, connection)
        update_query += update_query_version_conditions(version_attribute)
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

      def update_query_reset_version_columns(version_attribute)
        if version_attribute
          attr_partial     = version_attribute.to_s.pluralize # Changes resource_version/timestamp to resource_versions/timestamps
          attr_partial_max = "#{attr_partial}_max"

          # Quote the column names
          attr_partial     = quote_column_name(attr_partial)
          attr_partial_max = quote_column_name(attr_partial_max)

          # Full row update will reset the partial update timestamps
          <<-SQL
            , #{attr_partial} = '{}', #{attr_partial_max} = NULL
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
          WHERE updated_values.id = #{q_table_name}.id
        SQL
      end

      def update_query_version_conditions(version_attribute)
        if version_attribute
          # This conditional will avoid rewriting new data by old data. But we want it only when version_attribute is
          # a part of the data, since for the fake records, we just want to update ems_ref.
          attr_partial     = version_attribute.to_s.pluralize # Changes resource_version/timestamp to resource_versions/timestamps
          attr_partial_max = "#{attr_partial}_max"

          # Quote the column names
          attr_full        = quote_column_name(version_attribute)
          attr_partial_max = quote_column_name(attr_partial_max)

          <<-SQL
            AND (
              updated_values.#{attr_full} IS NULL OR (
                (#{q_table_name}.#{attr_full} IS NULL OR updated_values.#{attr_full} > #{q_table_name}.#{attr_full}) AND
                (#{q_table_name}.#{attr_partial_max} IS NULL OR updated_values.#{attr_full} >= #{q_table_name}.#{attr_partial_max})
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
