module ManagerRefresh::SaveCollection
  module Saver
    class ConcurrentSafeBatch < ManagerRefresh::SaveCollection::Saver::Base
      private

      def save!(inventory_collection, association)
        attributes_index        = {}
        inventory_objects_index = {}
        all_attribute_keys      = Set.new

        inventory_collection.each do |inventory_object|
          attributes = inventory_object.attributes(inventory_collection)
          index      = inventory_object.manager_uuid

          attributes_index[index]        = attributes
          inventory_objects_index[index] = inventory_object
          all_attribute_keys.merge(attributes_index[index].keys)
        end

        all_attribute_keys << :last_sync_on if inventory_collection.supports_last_sync_on?
        all_attribute_keys += [:created_on, :updated_on] if inventory_collection.supports_timestamps_on_variant?
        all_attribute_keys += [:created_at, :updated_at] if inventory_collection.supports_timestamps_at_variant?

        _log.info("*************** PROCESSING #{inventory_collection} of size #{inventory_collection.size} *************")
        hashes_for_update = []
        records_for_destroy = []

        # Records that are in the DB, we will be updating or deleting them.
        association.find_in_batches do |batch|
          update_time = time_now
          batch.each do |record|
            next unless assert_distinct_relation(record)

            index = inventory_collection.object_index_with_keys(unique_index_keys, record)

            inventory_object = inventory_objects_index.delete(index)
            hash             = attributes_index.delete(index)

            if inventory_object.nil?
              # Record was found in the DB but not sent for saving, that means it doesn't exist anymore and we should
              # delete it from the DB.
              if inventory_collection.delete_allowed?
                records_for_destroy << record
              end
            else
              # Record was found in the DB and sent for saving, we will be updating the DB.
              next unless assert_referential_integrity(hash, inventory_object)
              inventory_object.id = record.id

              hash_for_update = if inventory_collection.use_ar_object?
                                  record.assign_attributes(hash.except(:id, :type))
                                  values_for_database(inventory_collection.model_class,
                                                      all_attribute_keys,
                                                      record.attributes)
                                else
                                  hash.symbolize_keys
                                end
              assign_attributes_for_update!(hash_for_update, inventory_collection, update_time)

              hashes_for_update << hash_for_update.except(:id, :type)
            end
          end

          # Update in batches
          if hashes_for_update.size >= batch_size
            update_records!(inventory_collection, all_attribute_keys, hashes_for_update)
            inventory_collection.store_updated_records(hashes_for_update)

            hashes_for_update = []
          end

          # Destroy in batches
          if records_for_destroy.size >= batch_size
            destroy_records(records_for_destroy)
            inventory_collection.store_deleted_records(records_for_destroy)
            records_for_destroy = []
          end
        end

        # Update the last batch
        update_records!(inventory_collection, all_attribute_keys, hashes_for_update)
        hashes_for_update = [] # Cleanup so GC can release it sooner

        # Destroy the last batch
        destroy_records(records_for_destroy)
        records_for_destroy = [] # Cleanup so GC can release it sooner

        all_attribute_keys << :type if inventory_collection.supports_sti?
        # Records that were not found in the DB but sent for saving, we will be creating these in the DB.
        if inventory_collection.create_allowed?
          inventory_objects_index.each_slice(batch_size) do |batch|
            create_records!(inventory_collection, all_attribute_keys, batch, attributes_index)
          end
        end
        _log.info("*************** PROCESSED #{inventory_collection}, "\
                  "created=#{inventory_collection.created_records.count}, "\
                  "updated=#{inventory_collection.updated_records.count}, "\
                  "deleted=#{inventory_collection.deleted_records.count} *************")
      end

      def destroy_records(records)
        # TODO(lsmola) we need at least batch disconnect. Batch destroy won't be probably possible because of the
        # :dependent => :destroy.
        ActiveRecord::Base.transaction do
          records.each do |record|
            delete_record!(inventory_collection, record)
          end
        end
      end

      def update_records!(inventory_collection, all_attribute_keys, hashes)
        return if hashes.blank?

        ActiveRecord::Base.connection.execute(build_update_query(inventory_collection, all_attribute_keys, hashes))
      end

      def create_records!(inventory_collection, all_attribute_keys, batch, attributes_index)
        indexed_inventory_objects = {}
        hashes = []
        create_time = time_now
        batch.each do |index, inventory_object|
          hash = if inventory_collection.use_ar_object?
                   record = inventory_collection.model_class.new(attributes_index.delete(index))
                   values_for_database(inventory_collection.model_class,
                                       all_attribute_keys,
                                       record.attributes)
                 else
                   attributes_index.delete(index).symbolize_keys
                 end

          assign_attributes_for_create!(hash, inventory_collection, create_time)

          next unless assert_referential_integrity(hash, inventory_object)
          inventory_collection.store_created_records(hash)

          hashes << hash
          # Index on Unique Columns values, so we can easily fill in the :id later
          indexed_inventory_objects[inventory_collection.unique_index_columns.map { |x| hash[x] }] = inventory_object
        end

        return if hashes.blank?

        result = ActiveRecord::Base.connection.execute(
          build_insert_query(inventory_collection, all_attribute_keys, hashes)
        )
        if inventory_collection.dependees.present?
          # We need to get primary keys of the created objects, but only if there are dependees that would use them
          map_ids_to_inventory_objects(inventory_collection, indexed_inventory_objects, all_attribute_keys, hashes, result)
        end
      end

      def values_for_database(model_class, all_attribute_keys, attributes)
        all_attribute_keys.each_with_object({}) do |attribute_name, db_values|
          type = model_class.type_for_attribute(attribute_name.to_s)
          raw_val = attributes[attribute_name.to_s]
          db_values[attribute_name] = type.type == :boolean ? type.cast(raw_val) : type.serialize(raw_val)
        end
      end

      def map_ids_to_inventory_objects(inventory_collection, indexed_inventory_objects, all_attribute_keys, hashes, result)
        # The remote_data_timestamp is adding a WHERE condition to ON CONFLICT UPDATE. As a result, the RETURNING
        # clause is not guaranteed to return all ids of the inserted/updated records in the result. In that case
        # we test if the number of results matches the expected batch size. Then if the counts do not match, the only
        # safe option is to query all the data from the DB, using the unique_indexes. The batch size will also not match
        # for every remainders(a last batch in a stream of batches)
        if !supports_remote_data_timestamp?(all_attribute_keys) || result.count == batch_size
          result.each do |inserted_record|
            key                 = inventory_collection.unique_index_columns.map { |x| inserted_record[x.to_s] }
            inventory_object    = indexed_inventory_objects[key]
            inventory_object.id = inserted_record["id"] if inventory_object
          end
        else
          inventory_collection.model_class.where(
            build_multi_selection_query(inventory_collection, hashes)
          ).select(inventory_collection.unique_index_columns + [:id]).each do |inserted_record|
            key                 = inventory_collection.unique_index_columns.map { |x| inserted_record.public_send(x) }
            inventory_object    = indexed_inventory_objects[key]
            inventory_object.id = inserted_record.id if inventory_object
          end
        end
      end
    end
  end
end
