module ManagerRefresh::SaveCollection
  module Helper
    def save_inventory_object_inventory(ems, inventory_collection)
      _log.info("Synchronizing #{ems.name} collection #{inventory_collection} of size #{inventory_collection.size} to"\
                " the database")

      if inventory_collection.custom_save_block.present?
        _log.info("Synchronizing #{ems.name} collection #{inventory_collection} using a custom save block")
        inventory_collection.custom_save_block.call(ems, inventory_collection)
      else
        save_inventory(inventory_collection)
      end
      _log.info("Synchronized #{ems.name} collection #{inventory_collection}")
      inventory_collection.saved = true
    end

    private

    def save_inventory(inventory_collection)
      inventory_collection.parent.reload if inventory_collection.parent
      association = inventory_collection.db_collection_for_comparison

      save_inventory_collection!(inventory_collection, association)
    end

    def save_inventory_collection!(inventory_collection, association)
      attributes_index        = {}
      inventory_objects_index = {}
      inventory_collection.each do |inventory_object|
        attributes = inventory_object.attributes(inventory_collection)
        index      = inventory_object.manager_uuid

        attributes_index[index]        = attributes
        inventory_objects_index[index] = inventory_object
      end

      unique_index_keys = inventory_collection.manager_ref_to_cols
      unique_db_indexes = Set.new

      inventory_collection_size = inventory_collection.size
      deleted_counter           = 0
      created_counter           = 0
      _log.info("*************** PROCESSING #{inventory_collection} of size #{inventory_collection_size} *************")
      ActiveRecord::Base.transaction do
        association.find_each do |record|
          index = inventory_collection.object_index_with_keys(unique_index_keys, record)
          if unique_db_indexes.include?(index) # Include on Set is O(1)
            # We have a duplicate in the DB, destroy it. A find_each method does automatically .order(:id => :asc)
            # so we always keep the oldest record in the case of duplicates.
            _log.warn("A duplicate record was detected and destroyed, inventory_collection: '#{inventory_collection}', "\
                      "record: '#{record}', duplicate_index: '#{index}'")
            record.destroy
          else
            unique_db_indexes << index
          end

          inventory_object = inventory_objects_index.delete(index)
          hash             = attributes_index.delete(index)

          if inventory_object.nil?
            next unless inventory_collection.delete_allowed?
            deleted_counter += 1
            record.public_send(inventory_collection.delete_method)
          else
            record.assign_attributes(hash.except(:id, :type))
            if inventory_collection.check_changed?
              record.save! if record.changed?
            else
              record.save!
            end

            inventory_object.id = record.id
          end
        end
      end

      if inventory_collection.create_allowed?
        ActiveRecord::Base.transaction do
          inventory_objects_index.each do |index, inventory_object|
            hash            = attributes_index.delete(index)
            record          = inventory_collection.model_class.create!(hash.except(:id))
            created_counter += 1

            inventory_object.id = record.id
          end
        end
      end

      _log.info("*************** PROCESSED #{inventory_collection}, created=#{created_counter}, "\
                "updated=#{inventory_collection_size - created_counter}, deleted=#{deleted_counter} *************")
    end
  end
end
