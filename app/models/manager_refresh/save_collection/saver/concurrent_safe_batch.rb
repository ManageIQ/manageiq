module ManagerRefresh::SaveCollection
  module Saver
    class ConcurrentSafeBatch < ManagerRefresh::SaveCollection::Saver::Base
      private

      delegate :association_to_base_class_mapping,
               :association_to_foreign_key_mapping,
               :association_to_foreign_type_mapping,
               :attribute_references,
               :to => :inventory_collection

      # Attribute accessor to ApplicationRecord object or Hash
      #
      # @param record [Hash, ApplicationRecord] record or hash
      # @param key [Symbol] key pointing to attribute of the record
      # @return [Object] value of the record on the key
      def record_key(record, key)
        send(record_key_method, record, key)
      end

      # Attribute accessor to ApplicationRecord object
      #
      # @param record [ApplicationRecord] record
      # @param key [Symbol] key pointing to attribute of the record
      # @return [Object] value of the record on the key
      def ar_record_key(record, key)
        record.public_send(key)
      end

      # Attribute accessor to Hash object
      #
      # @param record [Hash] hash
      # @param key [Symbol] key pointing to attribute of the record
      # @return [Object] value of the record on the key
      def pure_sql_record_key(record, key)
        record[select_keys_indexes[key]]
      end

      # Returns iterator or relation based on settings
      #
      # @param association [Symbol] An existing association on manager
      # @return [ActiveRecord::Relation, ManagerRefresh::ApplicationRecordIterator] iterator or relation based on settings
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
          # Normal Rails ActiveRecord::Relation where we can call find_in_batches or
          # ManagerRefresh::ApplicationRecordIterator passed from targeted refresh
          association
        end
      end

      # Saves the InventoryCollection
      #
      # @param association [Symbol] An existing association on manager
      def save!(association)
        attributes_index        = {}
        inventory_objects_index = {}
        all_attribute_keys      = Set.new + inventory_collection.batch_extra_attributes

        inventory_collection.each do |inventory_object|
          attributes = inventory_object.attributes_with_keys(inventory_collection, all_attribute_keys)
          index      = build_stringified_reference(attributes, unique_index_keys)

          # Interesting fact: not building attributes_index and using only inventory_objects_index doesn't do much
          # of a difference, since the most objects inside are shared.
          attributes_index[index]        = attributes
          inventory_objects_index[index] = inventory_object
        end

        all_attribute_keys << :created_at if supports_created_at?
        all_attribute_keys << :updated_at if supports_updated_at?
        all_attribute_keys << :created_on if supports_created_on?
        all_attribute_keys << :updated_on if supports_updated_on?
        all_attribute_keys << :type if supports_sti?

        _log.debug("Processing #{inventory_collection} of size #{inventory_collection.size}...")

        unless inventory_collection.create_only?
          update_or_destroy_records!(batch_iterator(association), inventory_objects_index, attributes_index, all_attribute_keys)
        end

        unless inventory_collection.create_only?
          inventory_collection.custom_reconnect_block&.call(inventory_collection, inventory_objects_index, attributes_index)
        end

        # Records that were not found in the DB but sent for saving, we will be creating these in the DB.
        if inventory_collection.create_allowed?
          on_conflict = inventory_collection.parallel_safe? ? :do_update : nil

          inventory_objects_index.each_slice(batch_size_for_persisting) do |batch|
            create_records!(all_attribute_keys, batch, attributes_index, :on_conflict => on_conflict)
          end

          # Let the GC clean this up
          inventory_objects_index = nil
          attributes_index = nil

          if inventory_collection.parallel_safe?
            create_or_update_partial_records(all_attribute_keys)
          end
        end
        _log.debug("Processing #{inventory_collection}, "\
                   "created=#{inventory_collection.created_records.count}, "\
                   "updated=#{inventory_collection.updated_records.count}, "\
                   "deleted=#{inventory_collection.deleted_records.count}...Complete")
      rescue => e
        _log.error("Error when saving #{inventory_collection} with #{inventory_collection_details}. Message: #{e.message}")
        raise e
      end

      # Batch updates existing records that are in the DB using attributes_index. And delete the ones that were not
      # present in inventory_objects_index.
      #
      # @param records_batch_iterator [ActiveRecord::Relation, ManagerRefresh::ApplicationRecordIterator] iterator or
      #        relation, both responding to :find_in_batches method
      # @param inventory_objects_index [Hash{String => ManagerRefresh::InventoryObject}] Hash of InventoryObject objects
      # @param attributes_index [Hash{String => Hash}] Hash of data hashes with only keys that are column names of the
      #        models's table
      # @param all_attribute_keys [Array<Symbol>] Array of all columns we will be saving into each table row
      def update_or_destroy_records!(records_batch_iterator, inventory_objects_index, attributes_index, all_attribute_keys)
        hashes_for_update   = []
        records_for_destroy = []
        indexed_inventory_objects = {}

        records_batch_iterator.find_in_batches(:batch_size => batch_size) do |batch|
          update_time = time_now

          batch.each do |record|
            primary_key_value = record_key(record, primary_key)

            next unless assert_distinct_relation(primary_key_value)

            index = db_columns_index(record)

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

              if inventory_collection.parallel_safe? &&
                 (supports_remote_data_timestamp?(all_attribute_keys) || supports_remote_data_version?(all_attribute_keys))

                version_attr, max_version_attr = if supports_remote_data_timestamp?(all_attribute_keys)
                                                   [:resource_timestamp, :resource_timestamps_max]
                                                 elsif supports_remote_data_version?(all_attribute_keys)
                                                   [:resource_version, :resource_versions_max]
                                                 end

                next if skeletonize_or_skip_record(record.try(version_attr) || record.try(:[], version_attr),
                                                   hash[version_attr],
                                                   record.try(max_version_attr) || record.try(:[], max_version_attr),
                                                   inventory_object)
              end

              hash_for_update = if inventory_collection.use_ar_object?
                                  record.assign_attributes(hash.except(:id))
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
              indexed_inventory_objects[index] = inventory_object
              hashes_for_update << hash_for_update
            end
          end

          # Update in batches
          if hashes_for_update.size >= batch_size_for_persisting
            update_records!(all_attribute_keys, hashes_for_update, indexed_inventory_objects)

            hashes_for_update = []
            indexed_inventory_objects = {}
          end

          # Destroy in batches
          if records_for_destroy.size >= batch_size_for_persisting
            destroy_records!(records_for_destroy)
            records_for_destroy = []
          end
        end

        # Update the last batch
        update_records!(all_attribute_keys, hashes_for_update, indexed_inventory_objects)
        hashes_for_update = [] # Cleanup so GC can release it sooner

        # Destroy the last batch
        destroy_records!(records_for_destroy)
        records_for_destroy = [] # Cleanup so GC can release it sooner
      end

      def db_columns_index(record, pure_sql: false)
        # Incoming values are in SQL string form.
        # TODO(lsmola) unify this behavior with object_index_with_keys method in InventoryCollection
        # TODO(lsmola) maybe we can drop the whole pure sql fetching, since everything will be targeted refresh
        # with streaming refresh? Maybe just metrics and events will not be, but those should be upsert only
        # TODO(lsmola) taking ^ in account, we can't drop pure sql, since that is returned by batch insert and
        # update queries
        unique_index_keys_to_s.map do |attribute|
          value = if pure_sql
                    record[attribute]
                  else
                    record_key(record, attribute)
                  end

          format_value(attribute, value)
        end.join("__")
      end

      def format_value(attribute, value)
        if attribute == "timestamp"
          # TODO: can this be covered by @deserializable_keys?
          type = model_class.type_for_attribute(attribute)
          type.cast(value).utc.iso8601.to_s
        elsif (type = deserializable_keys[attribute.to_sym])
          type.deserialize(value).to_s
        else
          value.to_s
        end
      end

      # Deletes or sof-deletes records. If the model_class supports a custom class delete method, we will use it for
      # batch soft-delete.
      #
      # @param records [Array<ApplicationRecord, Hash>] Records we want to delete. If we have only hashes, we need to
      #        to fetch ApplicationRecord objects from the DB
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

      # Batch updates existing records
      #
      # @param hashes [Array<Hash>] data used for building a batch update sql query
      # @param all_attribute_keys [Array<Symbol>] Array of all columns we will be saving into each table row
      def update_records!(all_attribute_keys, hashes, indexed_inventory_objects)
        return if hashes.blank?

        unless inventory_collection.parallel_safe?
          # We need to update the stored records before we save it, since hashes are modified
          inventory_collection.store_updated_records(hashes)
        end

        query = build_update_query(all_attribute_keys, hashes)
        result = get_connection.execute(query)

        if inventory_collection.parallel_safe?
          # We will check for timestamp clashes of full row update and we will fallback to skeletal update
          inventory_collection.store_updated_records(result)

          skeletonize_ignored_records!(indexed_inventory_objects, result)
        end

        result
      end

      # Taking result from update or upsert of the row. The records that were not saved will be turned into skeletal
      # records and we will save them attribute by attribute.
      #
      # @param hash [Hash{String => InventoryObject}>] Hash with indexed data we want to save
      # @param result [Array<Hash>] Result from the DB containing the data that were actually saved
      # @param all_unique_columns [Boolean] True if index is consisted from all columns of the unique index. False if
      #        index is just made from manager_ref turned in DB column names.
      def skeletonize_ignored_records!(hash, result, all_unique_columns: false)
        updated = if all_unique_columns
                    result.map { |x| unique_index_columns_to_s.map { |key| x[key] } }
                  else
                    result.map { |x| db_columns_index(x, :pure_sql => true) }
                  end

        updated.each { |x| hash.delete(x) }

        # Now lets skeletonize all inventory_objects that were not saved by update or upsert. Old rows that can't be
        # saved are not being sent here. We have only rows that are new, but become old as we send the query (so other
        # parallel process saved the data in the meantime). Or if some attributes are newer than the whole row
        # being sent.
        hash.each_key do |db_index|
          inventory_collection.skeletal_primary_index.skeletonize_primary_index(hash[db_index].manager_uuid)
        end
      end

      # Saves partial records using upsert, taking records from skeletal_primary_index. This is used both for
      # skeletal precreate as well as for saving partial rows.
      #
      # @param all_attribute_keys [Set] Superset of all keys of all records being saved
      def create_or_update_partial_records(all_attribute_keys)
        skeletal_attributes_index        = {}
        skeletal_inventory_objects_index = {}

        inventory_collection.skeletal_primary_index.each_value do |inventory_object|
          attributes = inventory_object.attributes_with_keys(inventory_collection, all_attribute_keys)
          index      = build_stringified_reference(attributes, unique_index_keys)

          skeletal_attributes_index[index]        = attributes
          skeletal_inventory_objects_index[index] = inventory_object
        end

        if supports_remote_data_timestamp?(all_attribute_keys)
          all_attribute_keys << :resource_timestamps
          all_attribute_keys << :resource_timestamps_max
        elsif supports_remote_data_version?(all_attribute_keys)
          all_attribute_keys << :resource_versions
          all_attribute_keys << :resource_versions_max
        end

        indexed_inventory_objects = {}
        hashes                    = []
        create_time               = time_now

        skeletal_inventory_objects_index.each do |index, inventory_object|
          hash = skeletal_attributes_index.delete(index)
          # Partial create or update must never set a timestamp for the whole row
          timestamps = if supports_remote_data_timestamp?(all_attribute_keys) && supports_resource_timestamps_max?
                         assign_partial_row_version_attributes!(:resource_timestamp,
                                                                :resource_timestamps,
                                                                :resource_timestamps_max,
                                                                hash,
                                                                all_attribute_keys)
                       elsif supports_remote_data_version?(all_attribute_keys) && supports_resource_versions_max?
                         assign_partial_row_version_attributes!(:resource_version,
                                                                :resource_versions,
                                                                :resource_versions_max,
                                                                hash,
                                                                all_attribute_keys)
                       end
          # Transform hash to DB format
          hash = transform_to_hash!(all_attribute_keys, hash)

          assign_attributes_for_create!(hash, create_time)

          next unless assert_referential_integrity(hash)

          hash[:__non_serialized_versions] = timestamps # store non serialized timestamps for the partial updates
          hashes << hash
          # Index on Unique Columns values, so we can easily fill in the :id later
          indexed_inventory_objects[unique_index_columns.map { |x| hash[x] }] = inventory_object
        end

        return if hashes.blank?

        # First, lets try to create all partial records
        hashes.each_slice(batch_size_for_persisting) do |batch|
          result = create_partial!(all_attribute_keys,
                                   batch,
                                   :on_conflict => :do_nothing)
          inventory_collection.store_created_records(result)
        end

        # We need only skeletal records with timestamp. We can't save the ones without timestamp, because e.g. skeletal
        # precreate would be updating records with default values, that are not correct.
        pre_filtered = hashes.select { |x| x[:resource_timestamps_max] || x[:resource_versions_max] }

        results = {}
        # TODO(lsmola) we don't need to process rows that were save by the create -> oncoflict do nothing
        (all_attribute_keys - inventory_collection.base_columns).each do |column_name|
          filtered = pre_filtered.select { |x| x.key?(column_name) }

          filtered.each_slice(batch_size_for_persisting) do |batch|
            # We need to set correct timestamps_max for this particular attribute, based on what is in timestamps
            if supports_remote_data_timestamp?(all_attribute_keys)
              batch.each { |x| x[:resource_timestamps_max] = x[:__non_serialized_versions][column_name] if x[:__non_serialized_versions][column_name] }
            elsif supports_remote_data_version?(all_attribute_keys)
              batch.each { |x| x[:resource_versions_max] = x[:__non_serialized_versions][column_name] if x[:__non_serialized_versions][column_name] }
            end

            result = create_partial!(inventory_collection.base_columns + [column_name],
                                     batch,
                                     :on_conflict => :do_update,
                                     :column_name => column_name)
            result.each do |res|
              results[res["id"]] = res
            end
          end
        end

        inventory_collection.store_updated_records(results.values)

        # TODO(lsmola) we need to move here the hash loading ar object etc. otherwise the lazy_find with key will not
        # be correct
        if inventory_collection.dependees.present?
          # We need to get primary keys of the created objects, but only if there are dependees that would use them
          map_ids_to_inventory_objects(indexed_inventory_objects,
                                       all_attribute_keys,
                                       hashes,
                                       nil,
                                       :on_conflict => :do_nothing)
        end
      end

      # Batch upserts 1 data column of the row, plus the internal columns
      #
      # @param all_attribute_keys [Array<Symbol>] Array of all columns we will be saving into each table row
      # @param hashes [Array<ManagerRefresh::InventoryObject>] Array of InventoryObject objects we will be inserting
      #        into the DB
      # @param on_conflict [Symbol, NilClass] defines behavior on conflict with unique index constraint, allowed values
      #        are :do_update, :do_nothing, nil
      # @param column_name [Symbol] Name of the data column we will be upserting
      def create_partial!(all_attribute_keys, hashes, on_conflict: nil, column_name: nil)
        get_connection.execute(
          build_insert_query(all_attribute_keys, hashes, :on_conflict => on_conflict, :mode => :partial, :column_name => column_name)
        )
      end

      # Batch inserts records using attributes_index data. With on_conflict option using :do_update, this method
      # does atomic upsert.
      #
      # @param all_attribute_keys [Array<Symbol>] Array of all columns we will be saving into each table row
      # @param batch [Array<ManagerRefresh::InventoryObject>] Array of InventoryObject object we will be inserting into
      #        the DB
      # @param attributes_index [Hash{String => Hash}] Hash of data hashes with only keys that are column names of the
      #        models's table
      # @param on_conflict [Symbol, NilClass] defines behavior on conflict with unique index constraint, allowed values
      #        are :do_update, :do_nothing, nil
      def create_records!(all_attribute_keys, batch, attributes_index, on_conflict: nil)
        indexed_inventory_objects = {}
        hashes                    = []
        create_time               = time_now
        batch.each do |index, inventory_object|
          hash = if inventory_collection.use_ar_object?
                   record = inventory_collection.model_class.new(attributes_index[index])
                   values_for_database!(all_attribute_keys,
                                        record.attributes.symbolize_keys)
                 elsif serializable_keys?
                   values_for_database!(all_attribute_keys,
                                        attributes_index[index])
                 else
                   attributes_index[index]
                 end

          assign_attributes_for_create!(hash, create_time)

          next unless assert_referential_integrity(hash)

          hashes << hash
          # Index on Unique Columns values, so we can easily fill in the :id later
          indexed_inventory_objects[unique_index_columns.map { |x| hash[x] }] = inventory_object
        end

        return if hashes.blank?

        result = get_connection.execute(
          build_insert_query(all_attribute_keys, hashes, :on_conflict => on_conflict, :mode => :full)
        )

        if inventory_collection.parallel_safe?
          # We've done upsert, so records were either created or updated. We can recognize that by checking if
          # created and updated timestamps are the same
          created_attr = "created_on" if inventory_collection.supports_created_on?
          created_attr ||= "created_at" if inventory_collection.supports_created_at?
          updated_attr = "updated_on" if inventory_collection.supports_updated_on?
          updated_attr ||= "updated_at" if inventory_collection.supports_updated_at?

          if created_attr && updated_attr
            created, updated = result.to_a.partition { |x| x[created_attr] == x[updated_attr] }
            inventory_collection.store_created_records(created)
            inventory_collection.store_updated_records(updated)
          else
            # The record doesn't have both created and updated attrs, so we'll take all as created
            inventory_collection.store_created_records(result)
          end
        else
          # We've done just insert, so all records were created
          inventory_collection.store_created_records(result)
        end

        if inventory_collection.dependees.present?
          # We need to get primary keys of the created objects, but only if there are dependees that would use them
          map_ids_to_inventory_objects(indexed_inventory_objects,
                                       all_attribute_keys,
                                       hashes,
                                       result,
                                       :on_conflict => on_conflict)
        end

        if inventory_collection.parallel_safe?
          skeletonize_ignored_records!(indexed_inventory_objects, result, :all_unique_columns => true)
        end
      end

      # Stores primary_key values of created records into associated InventoryObject objects.
      #
      # @param indexed_inventory_objects [Hash{String => ManagerRefresh::InventoryObject}] inventory objects indexed
      #        by stringified value made from db_columns
      # @param all_attribute_keys [Array<Symbol>] Array of all columns we will be saving into each table row
      # @param hashes [Array<Hashes>] Array of hashes that were used for inserting of the data
      # @param result [Array<Hashes>] Array of hashes that are a result of the batch insert query, each result
      #        contains a primary key_value plus all columns that are a part of the unique index
      # @param on_conflict [Symbol, NilClass] defines behavior on conflict with unique index constraint, allowed values
      #        are :do_update, :do_nothing, nil
      def map_ids_to_inventory_objects(indexed_inventory_objects, all_attribute_keys, hashes, result, on_conflict:)
        if on_conflict == :do_nothing
          # TODO(lsmola) is the comment below still accurate? We will update some partial rows, the actual skeletal
          # precreate will still do nothing.
          # For ON CONFLICT DO NOTHING, we need to always fetch the records plus the attribute_references. This path
          # applies only for skeletal precreate.
          inventory_collection.model_class.where(
            build_multi_selection_query(hashes)
          ).select(unique_index_columns + [:id] + attribute_references.to_a).each do |record|
            key              = unique_index_columns.map { |x| record.public_send(x) }
            inventory_object = indexed_inventory_objects[key]

            # Load also attribute_references, so lazy_find with :key pointing to skeletal reference works
            attributes = record.attributes.symbolize_keys
            attribute_references.each do |ref|
              inventory_object[ref] = attributes[ref]

              next unless (foreign_key = association_to_foreign_key_mapping[ref])
              base_class_name       = attributes[association_to_foreign_type_mapping[ref].try(:to_sym)] || association_to_base_class_mapping[ref]
              id                    = attributes[foreign_key.to_sym]
              inventory_object[ref] = ManagerRefresh::ApplicationRecordReference.new(base_class_name, id)
            end

            inventory_object.id = record.id if inventory_object
          end
        elsif !supports_remote_data_timestamp?(all_attribute_keys) || result.count == batch_size_for_persisting
          # We can use the insert query result to fetch all primary_key values, which makes this the most effective
          # path.
          result.each do |inserted_record|
            key = unique_index_columns.map do |x|
              value = inserted_record[x.to_s]
              type = deserializable_keys[x]
              type ? type.deserialize(value) : value
            end
            inventory_object    = indexed_inventory_objects[key]
            inventory_object.id = inserted_record[primary_key] if inventory_object
          end
        else
          # The remote_data_timestamp is adding a WHERE condition to ON CONFLICT UPDATE. As a result, the RETURNING
          # clause is not guaranteed to return all ids of the inserted/updated records in the result. In that case
          # we test if the number of results matches the expected batch size. Then if the counts do not match, the only
          # safe option is to query all the data from the DB, using the unique_indexes. The batch size will also not match
          # for every remainders(a last batch in a stream of batches)
          inventory_collection.model_class.where(
            build_multi_selection_query(hashes)
          ).select(unique_index_columns + [:id]).each do |inserted_record|
            key                 = unique_index_columns.map { |x| inserted_record.public_send(x) }
            inventory_object    = indexed_inventory_objects[key]
            inventory_object.id = inserted_record.id if inventory_object
          end
        end
      end

      def skeletonize_or_skip_record(record_version, hash_version, record_versions_max, inventory_object)
        # Skip updating this record, because it is old
        return true if record_version && hash_version && record_version >= hash_version

        # Some column has bigger version than the whole row, we need to store the row partially
        if record_versions_max && hash_version && record_versions_max > hash_version
          inventory_collection.skeletal_primary_index.skeletonize_primary_index(inventory_object.manager_uuid)
          return true
        end

        false
      end

      def assign_partial_row_version_attributes!(full_row_version_attr, partial_row_version_attr,
                                                 partial_row_version_attr_max, hash, all_attribute_keys)
        hash[partial_row_version_attr_max] = hash.delete(full_row_version_attr)

        if hash[partial_row_version_attr].present?
          # Lets clean to only what we save, since when we build the skeletal object, we can set more
          hash[partial_row_version_attr] = hash[partial_row_version_attr].slice(*all_attribute_keys)
        end
      end
    end
  end
end
