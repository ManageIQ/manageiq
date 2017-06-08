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

        inventory_collection_size = inventory_collection.size
        deleted_counter           = 0
        created_counter           = 0
        updated_counter           = 0
        _log.info("*************** PROCESSING #{inventory_collection} of size #{inventory_collection_size} *************")
        hashes_for_update = []
        records_for_destroy = []

        # Records that are in the DB, we will be updating or deleting them.
        association.find_in_batches do |batch|
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
                deleted_counter += 1
              end
            else
              # Record was found in the DB and sent for saving, we will be updating the DB.
              next unless assert_referential_integrity(hash, inventory_object)
              inventory_object.id = record.id

              record.assign_attributes(hash.except(:id, :type))
              if !inventory_collection.check_changed? || record.changed?
                hashes_for_update << record.attributes.symbolize_keys
              end
            end
          end

          # Update in batches
          if hashes_for_update.size >= batch_size
            update_records!(inventory_collection, all_attribute_keys, hashes_for_update)
            updated_counter += hashes_for_update.count

            hashes_for_update = []
          end

          # Destroy in batches
          if records_for_destroy.size >= batch_size
            destroy_records(records)
            records_for_destroy = []
          end
        end

        # Update the last batch
        update_records!(inventory_collection, all_attribute_keys, hashes_for_update)
        updated_counter += hashes_for_update.count
        hashes_for_update = [] # Cleanup so GC can release it sooner

        # Destroy the last batch
        destroy_records(records_for_destroy)
        records_for_destroy = [] # Cleanup so GC can release it sooner

        all_attribute_keys << :type if inventory_collection.supports_sti?
        # Records that were not found in the DB but sent for saving, we will be creating these in the DB.
        if inventory_collection.create_allowed?
          inventory_objects_index.each_slice(batch_size) do |batch|
            create_records!(inventory_collection, all_attribute_keys, batch, attributes_index)
            created_counter += batch.size
          end
        end
        _log.info("*************** PROCESSED #{inventory_collection}, created=#{created_counter}, "\
                  "updated=#{updated_counter}, deleted=#{deleted_counter} *************")
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
        batch.each do |index, inventory_object|
          hash = inventory_collection.model_class.new(attributes_index.delete(index)).attributes.symbolize_keys
          next unless assert_referential_integrity(hash, inventory_object)

          hashes << hash
          # Index on Unique Columns values, so we can easily fill in the :id later
          indexed_inventory_objects[inventory_collection.unique_index_columns.map { |x| hash[x] }] = inventory_object
        end

        return if hashes.blank?

        ActiveRecord::Base.connection.execute(
          build_insert_query(inventory_collection, all_attribute_keys, hashes)
        )
        if inventory_collection.dependees.present?
          # We need to get primary keys of the created objects, but only if there are dependees that would use them
          map_ids_to_inventory_objects(inventory_collection, indexed_inventory_objects, hashes)
        end
      end

      def map_ids_to_inventory_objects(inventory_collection, indexed_inventory_objects, hashes)
        inventory_collection.model_class.where(
          build_multi_selection_query(inventory_collection, hashes)
        ).find_each do |inserted_record|
          inventory_object = indexed_inventory_objects[inventory_collection.unique_index_columns.map { |x| inserted_record.public_send(x) }]
          inventory_object.id = inserted_record.id if inventory_object
        end
      end
    end
  end
end
