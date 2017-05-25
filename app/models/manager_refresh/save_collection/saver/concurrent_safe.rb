module ManagerRefresh::SaveCollection
  module Saver
    class ConcurrentSafe < ManagerRefresh::SaveCollection::Saver::Base
      private

      def save!(inventory_collection, association)
        attributes_index        = {}
        inventory_objects_index = {}
        inventory_collection.each do |inventory_object|
          attributes = inventory_object.attributes(inventory_collection)
          index      = inventory_object.manager_uuid

          attributes_index[index]        = attributes
          inventory_objects_index[index] = inventory_object
        end

        inventory_collection_size = inventory_collection.size
        deleted_counter           = 0
        created_counter           = 0
        _log.info("*************** PROCESSING #{inventory_collection} of size #{inventory_collection_size} *************")
        # Records that are in the DB, we will be updating or deleting them.
        association.find_in_batches do |batch|
          ActiveRecord::Base.transaction do
            batch.each do |record|
              next unless assert_distinct_relation(record)

              index = inventory_collection.object_index_with_keys(unique_index_keys, record)

              inventory_object = inventory_objects_index.delete(index)
              hash             = attributes_index.delete(index)

              if inventory_object.nil?
                # Record was found in the DB but not sent for saving, that means it doesn't exist anymore and we should
                # delete it from the DB.
                # TODO(lsmola) do a transaction for a batches of deletion
                deleted_counter += 1 if delete_record!(inventory_collection, record)
              else
                # Record was found in the DB and sent for saving, we will be updating the DB.
                update_record!(inventory_collection, record, hash, inventory_object)
              end
            end
          end
        end

        # Records that were not found in the DB but sent for saving, we will be creating these in the DB.
        if inventory_collection.create_allowed?
          inventory_objects_index.each_slice(1000) do |batch|
            ActiveRecord::Base.transaction do
              batch.each do |index, inventory_object|
                hash = attributes_index.delete(index)
                create_record!(inventory_collection, hash, inventory_object)
                created_counter += 1
              end
            end
          end
        end
        _log.info("*************** PROCESSED #{inventory_collection}, created=#{created_counter}, "\
                  "updated=#{inventory_collection_size - created_counter}, deleted=#{deleted_counter} *************")
      end

      def delete_record!(inventory_collection, record)
        return false unless inventory_collection.delete_allowed?
        record.public_send(inventory_collection.delete_method)
        true
      end

      def update_record!(inventory_collection, record, hash, inventory_object)
        record.assign_attributes(hash.except(:id, :type))

        # TODO(lsmola) ignore all N:M relations, since we use pure SQL, all N:M needs to be modeled as a separate IC, or
        # can we process those automatically? Using a convention? But still, it needs to be a separate IC, to have
        # efficient saving.
        hash.reject! { |_key, value| value.kind_of?(Array) }

        if !inventory_object.inventory_collection.check_changed? || record.changed?
          update_query = inventory_object.inventory_collection.model_class.where(:id => record.id)
          if hash[:remote_data_timestamp]
            timestamp_field = inventory_collection.model_class.arel_table[:remote_data_timestamp]
            update_query    = update_query.where(timestamp_field.lt(hash[:remote_data_timestamp]))
          end

          update_query.update_all(hash)
        end

        inventory_object.id = record.id
      end

      def create_record!(inventory_collection, hash, inventory_object)
        return unless assert_referential_integrity(hash, inventory_object)

        hash[:type]  = inventory_collection.model_class.name if inventory_collection.supports_sti? && hash[:type].blank?
        table_name   = inventory_object.inventory_collection.model_class.table_name
        insert_query = %{
        INSERT INTO #{table_name} (#{hash.keys.join(", ")})
          VALUES
            (
              #{hash.values.map { |x| ActiveRecord::Base.connection.quote(x) }.join(", ")}
            )
          ON CONFLICT (#{inventory_object.inventory_collection.unique_index_columns.join(", ")})
            DO
              UPDATE
                SET #{hash.keys.map { |x| "#{x} = EXCLUDED.#{x}" }.join(", ")}
        }
        # TODO(lsmola) do we want to exclude the ems_id from the UPDATE clause? Otherwise it might be difficult to change
        # the ems_id as a cross manager migration, since ems_id should be there as part of the insert. The attempt of
        # changing ems_id could lead to putting it back by a refresh.

        # This conditional will avoid rewriting new data by old data. But we want it only when remote_data_timestamp is a
        # part of the data, since for the fake records, we just want to update ems_ref.
        if hash[:remote_data_timestamp].present?
          insert_query += %{
          WHERE EXCLUDED.remote_data_timestamp IS NULL OR (EXCLUDED.remote_data_timestamp > #{table_name}.remote_data_timestamp)
        }
        end
        result_id           = ActiveRecord::Base.connection.insert_sql(insert_query)
        inventory_object.id = result_id
      end
    end
  end
end
