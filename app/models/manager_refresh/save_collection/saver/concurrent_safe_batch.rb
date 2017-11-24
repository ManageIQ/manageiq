module ManagerRefresh::SaveCollection
  module Saver
    class ConcurrentSafeBatch < ManagerRefresh::SaveCollection::Saver::Base
      private

      def record_key(record, key)
        send(record_key_method, record, key)
      end

      def ar_record_key(record, key)
        record.public_send(key)
      end

      def pure_sql_record_key(record, key)
        record[select_keys_indexes[key]]
      end

      def batch_iterator(association)
        if pure_sql_records_fetching
          # Building fast iterator doing pure SQL query and therefore avoiding redundant creation of AR objects. The
          # iterator responds to find_in_batches, so it acts like the AR relation. For targeted refresh, the association
          # can already be ApplicationRecordIterator, so we will skip that.
          pure_sql_iterator = lambda do |&block|
            primary_key_offset = nil
            loop do
              relation    = association.select(*select_keys)
                                       .reorder("#{primary_key} ASC")
                                       .limit(batch_size)
              # Using rails way of comparing primary key instead of offset
              relation    = relation.where(arel_primary_key.gt(primary_key_offset)) if primary_key_offset
              records     = get_connection.query(relation.to_sql)
              last_record = records.last
              block.call(records)

              break if records.size < batch_size
              primary_key_offset = record_key(last_record, primary_key)
            end
          end

          ManagerRefresh::ApplicationRecordIterator.new(:iterator => pure_sql_iterator)
        else
          # Normal Rails relation where we can call find_in_batches
          association
        end
      end

      def save!(association)
        attributes_index        = {}
        inventory_objects_index = {}
        all_attribute_keys      = Set.new + inventory_collection.batch_extra_attributes

        inventory_collection.each do |inventory_object|
          attributes = inventory_object.attributes_with_keys(inventory_collection, all_attribute_keys)
          index      = inventory_collection.hash_index_with_keys(unique_index_keys, attributes)

          # Interesting fact: not building attributes_index and using only inventory_objects_index doesn't do much
          # of a difference, since the most objects inside are shared.
          attributes_index[index]        = attributes
          inventory_objects_index[index] = inventory_object
        end

        all_attribute_keys << :created_at if supports_created_at?
        all_attribute_keys << :updated_at if supports_updated_at?
        all_attribute_keys << :created_on if supports_created_on?
        all_attribute_keys << :updated_on if supports_updated_on?

        _log.info("*************** PROCESSING #{inventory_collection} of size #{inventory_collection.size} *************")

        update_or_destroy_records!(batch_iterator(association), inventory_objects_index, attributes_index, all_attribute_keys)

        unless inventory_collection.custom_reconnect_block.nil?
          inventory_collection.custom_reconnect_block.call(inventory_collection, inventory_objects_index, attributes_index)
        end

        all_attribute_keys << :type if supports_sti?
        # Records that were not found in the DB but sent for saving, we will be creating these in the DB.
        if inventory_collection.create_allowed?
          inventory_objects_index.each_slice(batch_size_for_persisting) do |batch|
            create_records!(all_attribute_keys, batch, attributes_index)
          end
        end
        _log.info("*************** PROCESSED #{inventory_collection}, "\
                  "created=#{inventory_collection.created_records.count}, "\
                  "updated=#{inventory_collection.updated_records.count}, "\
                  "deleted=#{inventory_collection.deleted_records.count} *************")
      rescue => e
        _log.error("Error when saving #{inventory_collection} with #{inventory_collection_details}. Message: #{e.message}")
        raise e
      end

      def update_or_destroy_records!(records_batch_iterator, inventory_objects_index, attributes_index, all_attribute_keys)
        hashes_for_update   = []
        records_for_destroy = []

        records_batch_iterator.find_in_batches(:batch_size => batch_size) do |batch|
          update_time = time_now

          batch.each do |record|
            primary_key_value = record_key(record, primary_key)

            next unless assert_distinct_relation(primary_key_value)

            # TODO(lsmola) unify this behavior with object_index_with_keys method in InventoryCollection
            index = unique_index_keys_to_s.map do |attribute|
              if attribute == "timestamp"
                type = model_class.type_for_attribute(attribute)
                type.cast(record_key(record, attribute)).utc.iso8601.to_s
              else
                record_key(record, attribute).to_s
              end
            end.join(inventory_collection.stringify_joiner)

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
              next unless assert_referential_integrity(hash)
              inventory_object.id = primary_key_value

              hash_for_update = if inventory_collection.use_ar_object?
                                  record.assign_attributes(hash.except(:id, :type))
                                  values_for_database!(all_attribute_keys,
                                                       record.attributes.symbolize_keys)
                                elsif serializable_keys?
                                  # TODO(lsmola) hash data with current DB data to allow subset of data being sent,
                                  # otherwise we would nullify the not sent attributes. Test e.g. on disks in cloud
                                  values_for_database!(all_attribute_keys,
                                                       hash)
                                else
                                  # TODO(lsmola) hash data with current DB data to allow subset of data being sent,
                                  # otherwise we would nullify the not sent attributes. Test e.g. on disks in cloud
                                  hash
                                end
              assign_attributes_for_update!(hash_for_update, update_time)

              hash_for_update[:id] = primary_key_value
              hashes_for_update << hash_for_update
            end
          end

          # Update in batches
          if hashes_for_update.size >= batch_size_for_persisting
            update_records!(all_attribute_keys, hashes_for_update)

            hashes_for_update = []
          end

          # Destroy in batches
          if records_for_destroy.size >= batch_size_for_persisting
            destroy_records!(records_for_destroy)
            records_for_destroy = []
          end
        end

        # Update the last batch
        update_records!(all_attribute_keys, hashes_for_update)
        hashes_for_update = [] # Cleanup so GC can release it sooner

        # Destroy the last batch
        destroy_records!(records_for_destroy)
        records_for_destroy = [] # Cleanup so GC can release it sooner
      end

      def destroy_records!(records)
        return false unless inventory_collection.delete_allowed?
        return if records.blank?

        # Is the delete_method rails standard deleting method?
        rails_delete = %i(destroy delete).include?(inventory_collection.delete_method)
        if !rails_delete && inventory_collection.model_class.respond_to?(inventory_collection.delete_method)
          # We have custom delete method defined on a class, that means it supports batch destroy
          inventory_collection.store_deleted_records(records.map { |x| {:id => record_key(x, primary_key)} })
          inventory_collection.model_class.public_send(inventory_collection.delete_method, records.map { |x| record_key(x, primary_key) })
        else
          # We have either standard :destroy and :delete rails method, or custom instance level delete method
          # Note: The standard :destroy and :delete rails method can't be batched because of the hooks and cascade destroy
          ActiveRecord::Base.transaction do
            if pure_sql_records_fetching
              # For pure SQL fetching, we need to get the AR objects again, so we can call destroy
              inventory_collection.model_class.where(:id => records.map { |x| record_key(x, primary_key) }).find_each do |record|
                delete_record!(record)
              end
            else
              records.each do |record|
                delete_record!(record)
              end
            end
          end
        end
      end

      def update_records!(all_attribute_keys, hashes)
        return if hashes.blank?
        inventory_collection.store_updated_records(hashes)
        query = build_update_query(all_attribute_keys, hashes)
        get_connection.execute(query)
      end

      def create_records!(all_attribute_keys, batch, attributes_index)
        indexed_inventory_objects = {}
        hashes                    = []
        create_time               = time_now
        batch.each do |index, inventory_object|
          hash = if inventory_collection.use_ar_object?
                   record = inventory_collection.model_class.new(attributes_index.delete(index))
                   values_for_database!(all_attribute_keys,
                                        record.attributes.symbolize_keys)
                 elsif serializable_keys?
                   values_for_database!(all_attribute_keys,
                                        attributes_index.delete(index))
                 else
                   attributes_index.delete(index)
                 end

          assign_attributes_for_create!(hash, create_time)

          next unless assert_referential_integrity(hash)

          hashes << hash
          # Index on Unique Columns values, so we can easily fill in the :id later
          indexed_inventory_objects[unique_index_columns.map { |x| hash[x] }] = inventory_object
        end

        return if hashes.blank?

        result = get_connection.execute(
          build_insert_query(all_attribute_keys, hashes)
        )
        inventory_collection.store_created_records(result)
        if inventory_collection.dependees.present?
          # We need to get primary keys of the created objects, but only if there are dependees that would use them
          map_ids_to_inventory_objects(indexed_inventory_objects, all_attribute_keys, hashes, result)
        end
      end

      def values_for_database!(all_attribute_keys, attributes)
        all_attribute_keys.each do |key|
          if (type = serializable_keys[key])
            attributes[key] = type.serialize(attributes[key])
          end
        end
        attributes
      end

      def map_ids_to_inventory_objects(indexed_inventory_objects, all_attribute_keys, hashes, result)
        # The remote_data_timestamp is adding a WHERE condition to ON CONFLICT UPDATE. As a result, the RETURNING
        # clause is not guaranteed to return all ids of the inserted/updated records in the result. In that case
        # we test if the number of results matches the expected batch size. Then if the counts do not match, the only
        # safe option is to query all the data from the DB, using the unique_indexes. The batch size will also not match
        # for every remainders(a last batch in a stream of batches)
        if !supports_remote_data_timestamp?(all_attribute_keys) || result.count == batch_size_for_persisting
          result.each do |inserted_record|
            key                 = unique_index_columns.map { |x| inserted_record[x.to_s] }
            inventory_object    = indexed_inventory_objects[key]
            inventory_object.id = inserted_record[primary_key] if inventory_object
          end
        else
          inventory_collection.model_class.where(
            build_multi_selection_query(hashes)
          ).select(unique_index_columns + [:id]).each do |inserted_record|
            key                 = unique_index_columns.map { |x| inserted_record.public_send(x) }
            inventory_object    = indexed_inventory_objects[key]
            inventory_object.id = inserted_record.id if inventory_object
          end
        end
      end
    end
  end
end
