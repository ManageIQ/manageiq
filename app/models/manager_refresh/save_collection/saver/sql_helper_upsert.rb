module ManagerRefresh::SaveCollection
  module Saver
    module SqlHelperUpsert
      # Builds ON CONFLICT UPDATE updating branch for one column identified by the passed key
      #
      # @param key [Symbol] key that is column name
      # @return [String] SQL clause for upserting one column
      def build_insert_set_cols(key)
        "#{quote_column_name(key)} = EXCLUDED.#{quote_column_name(key)}"
      end

      # @param all_attribute_keys [Array<Symbol>] Array of all columns we will be saving into each table row
      # @param hashes [Array<Hash>] data used for building a batch insert sql query
      # @param mode [Symbol] Mode for saving, allowed values are [:full, :partial], :full is when we save all
      #        columns of a row, :partial is when we save only few columns, so a partial row.
      # @param on_conflict [Symbol, NilClass] defines behavior on conflict with unique index constraint, allowed values
      #        are :do_update, :do_nothing, nil
      def build_insert_query(all_attribute_keys, hashes, on_conflict: nil, mode:, column_name: nil)
        _log.debug("Building insert query for #{inventory_collection} of size #{inventory_collection.size}...")

        # Cache the connection for the batch
        connection = get_connection
        # Ignore versioning columns that are set separately
        ignore_cols = mode == :partial ? [:resource_timestamp, :resource_version] : []
        # Make sure we don't send a primary_key for INSERT in any form, it could break PG sequencer
        all_attribute_keys_array = all_attribute_keys.to_a - [primary_key.to_s, primary_key.to_sym] - ignore_cols

        insert_query = insert_query_insert_values(hashes, all_attribute_keys_array, connection)
        insert_query += insert_query_on_conflict_behavior(all_attribute_keys, on_conflict, mode, ignore_cols, column_name)
        insert_query += insert_query_returning

        _log.debug("Building insert query for #{inventory_collection} of size #{inventory_collection.size}...Complete")

        insert_query
      end

      private

      def insert_query_insert_values(hashes, all_attribute_keys_array, connection)
        values = hashes.map do |hash|
          "(#{all_attribute_keys_array.map { |x| quote(connection, hash[x], x) }.join(",")})"
        end.join(",")

        col_names = all_attribute_keys_array.map { |x| quote_column_name(x) }.join(",")

        <<-SQL
          INSERT INTO #{q_table_name} (#{col_names})
            VALUES
              #{values}
        SQL
      end

      def insert_query_on_conflict_behavior(all_attribute_keys, on_conflict, mode, ignore_cols, column_name)
        return "" unless inventory_collection.parallel_safe?

        insert_query_on_conflict = insert_query_on_conflict_do(on_conflict)
        if on_conflict == :do_update
          insert_query_on_conflict += insert_query_on_conflict_update(all_attribute_keys, mode, ignore_cols, column_name)
        end
        insert_query_on_conflict
      end

      def insert_query_on_conflict_do(on_conflict)
        if on_conflict == :do_nothing
          <<-SQL
            ON CONFLICT DO NOTHING
          SQL
        elsif on_conflict == :do_update
          index_where_condition = unique_index_for(unique_index_keys).where
          where_to_sql          = index_where_condition ? "WHERE #{index_where_condition}" : ""

          <<-SQL
            ON CONFLICT (#{unique_index_columns.map { |x| quote_column_name(x) }.join(",")}) #{where_to_sql}
              DO
                UPDATE
          SQL
        end
      end

      def insert_query_on_conflict_update(all_attribute_keys, mode, ignore_cols, column_name)
        if mode == :partial
          ignore_cols += [:resource_timestamps, :resource_timestamps_max, :resource_versions, :resource_versions_max]
        end
        ignore_cols += [:created_on, :created_at] # Lets not change created for the update clause

        # If there is not version attribute, the update part will be ignored below
        version_attribute = if supports_remote_data_timestamp?(all_attribute_keys)
                              :resource_timestamp
                            elsif supports_remote_data_version?(all_attribute_keys)
                              :resource_version
                            end

        # TODO(lsmola) should we add :deleted => false to the update clause? That should handle a reconnect, without a
        # a need to list :deleted anywhere in the parser. We just need to check that a model has the :deleted attribute
        query = <<-SQL
          SET #{(all_attribute_keys - ignore_cols).map { |key| build_insert_set_cols(key) }.join(", ")}
        SQL

        # This conditional will make sure we are avoiding rewriting new data by old data. But we want it only when
        # remote_data_timestamp is a part of the data.
        query += insert_query_on_conflict_update_mode(mode, version_attribute, column_name) if version_attribute
        query
      end

      def insert_query_on_conflict_update_mode(mode, version_attribute, column_name)
        if mode == :full
          full_update_condition(version_attribute)
        elsif mode == :partial
          raise "Column name must be provided" unless column_name
          partial_update_condition(version_attribute, column_name)
        end
      end

      def full_update_condition(attr_full)
        attr_partial = attr_full.to_s.pluralize # Changes resource_version/timestamp to resource_versions/timestamps
        attr_partial_max = "#{attr_partial}_max"

        # Quote the column names
        attr_full        = quote_column_name(attr_full)
        attr_partial     = quote_column_name(attr_partial)
        attr_partial_max = quote_column_name(attr_partial_max)

        <<-SQL
          , #{attr_partial} = '{}', #{attr_partial_max} = NULL

          WHERE EXCLUDED.#{attr_full} IS NULL OR (
            (#{q_table_name}.#{attr_full} IS NULL OR EXCLUDED.#{attr_full} > #{q_table_name}.#{attr_full}) AND
            (#{q_table_name}.#{attr_partial_max} IS NULL OR EXCLUDED.#{attr_full} >= #{q_table_name}.#{attr_partial_max})
          )
        SQL
      end

      def partial_update_condition(attr_full, column_name)
        attr_partial     = attr_full.to_s.pluralize # Changes resource_version/timestamp to resource_versions/timestamps
        attr_partial_max = "#{attr_partial}_max"
        cast             = if attr_full == :resource_timestamp
                             "timestamp"
                           elsif attr_full == :resource_version
                             "integer"
                           end

        # Quote the column names
        attr_full        = quote_column_name(attr_full)
        attr_partial     = quote_column_name(attr_partial)
        attr_partial_max = quote_column_name(attr_partial_max)
        column_name      = get_connection.quote_string(column_name.to_s)
        q_table_name     = get_connection.quote_table_name(table_name)

        <<-SQL
          #{insert_query_set_jsonb_version(cast, attr_partial, attr_partial_max, column_name)}
          , #{attr_partial_max} = greatest(#{q_table_name}.#{attr_partial_max}::#{cast}, EXCLUDED.#{attr_partial_max}::#{cast})
          WHERE EXCLUDED.#{attr_partial_max} IS NULL OR (
            (#{q_table_name}.#{attr_full} IS NULL OR EXCLUDED.#{attr_partial_max} > #{q_table_name}.#{attr_full}) AND (
              (#{q_table_name}.#{attr_partial}->>'#{column_name}')::#{cast} IS NULL OR
              EXCLUDED.#{attr_partial_max}::#{cast} > (#{q_table_name}.#{attr_partial}->>'#{column_name}')::#{cast}
            )
          )
        SQL
      end

      def insert_query_set_jsonb_version(cast, attr_partial, attr_partial_max, column_name)
        if cast == "integer"
          # If we have integer value, we don't want to encapsulate the value in ""
          <<-SQL
            , #{attr_partial} = #{q_table_name}.#{attr_partial} || ('{"#{column_name}": ' || EXCLUDED.#{attr_partial_max}::#{cast} || '}')::jsonb
          SQL
        else
          <<-SQL
            , #{attr_partial} = #{q_table_name}.#{attr_partial} || ('{"#{column_name}": "' || EXCLUDED.#{attr_partial_max}::#{cast} || '"}')::jsonb
          SQL
        end
      end

      def insert_query_returning
        <<-SQL
          RETURNING "id",#{unique_index_columns.map { |x| quote_column_name(x) }.join(",")}
                    #{insert_query_returning_timestamps}
        SQL
      end

      def insert_query_returning_timestamps
        if inventory_collection.parallel_safe?
          # For upsert, we'll return also created and updated timestamps, so we can recognize what was created and what
          # updated
          if inventory_collection.internal_timestamp_columns.present?
            <<-SQL
              , #{inventory_collection.internal_timestamp_columns.map { |x| quote_column_name(x) }.join(",")}
            SQL
          end
        else
          ""
        end
      end
    end
  end
end
