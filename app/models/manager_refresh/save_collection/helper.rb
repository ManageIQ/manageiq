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

    def log_format_deletes(deletes)
      ret = deletes.collect do |d|
        s = "id: [#{d.id}]"

        [:name, :product_name, :device_name].each do |k|
          next unless d.respond_to?(k)
          v = d.send(k)
          next if v.nil?
          s << " #{k}: [#{v}]"
          break
        end

        s
      end

      ret.join(", ")
    end

    private

    def save_inventory(inventory_collection)
      inventory_collection.parent.reload if inventory_collection.parent
      association  = inventory_collection.load_from_db
      record_index = {}

      create_or_update_inventory!(inventory_collection, record_index, association)

      # Delete only if InventoryCollection is complete. If it's not complete, we are sending only subset of the records,
      # so we cannot invoke deleting of the missing records.
      delete_inventory!(inventory_collection, record_index, association) if inventory_collection.delete_allowed?
    end

    def create_or_update_inventory!(inventory_collection, record_index, association)
      unique_index_keys = inventory_collection.manager_ref_to_cols

      association.find_each do |record|
        # TODO(lsmola) the old code was able to deal with duplicate records, should we do that? The old data still can
        # have duplicate methods, so we should clean them up. It will slow up the indexing though.
        record_index[inventory_collection.object_index_with_keys(unique_index_keys, record)] = record
      end

      entity_builder = get_entity_builder(inventory_collection, association)

      inventory_collection_size = inventory_collection.size
      created_counter           = 0
      _log.info("*************** PROCESSING #{inventory_collection} of size #{inventory_collection_size} ***************")
      ActiveRecord::Base.transaction do
        inventory_collection.each do |inventory_object|
          hash   = inventory_object.attributes(inventory_collection)
          record = record_index.delete(inventory_object.manager_uuid)
          if record.nil?
            next unless inventory_collection.create_allowed?
            record          = entity_builder.create!(hash.except(:id))
            created_counter += 1
          else
            record.assign_attributes(hash.except(:id, :type))
            if inventory_collection.check_changed?
              record.save! if record.changed?
            else
              record.save!
            end
          end
          inventory_object.id = record.try(:id)
        end
      end
      _log.info("*************** PROCESSED #{inventory_collection}, created=#{created_counter}, "\
                "updated=#{inventory_collection_size - created_counter} ***************")
    end

    def delete_inventory!(inventory_collection, record_index, association)
      # Delete the items no longer found
      unless record_index.blank?
        deletes = record_index.values
        _log.info("*************** DELETING #{inventory_collection} of size #{deletes.size} ***************")
        type = association.proxy_association.reflection.name
        _log.info("[#{type}] Deleting with method '#{inventory_collection.delete_method}' #{log_format_deletes(deletes)}")
        ActiveRecord::Base.transaction do
          deletes.map(&inventory_collection.delete_method)
        end
        _log.info("*************** DELETED #{inventory_collection} ***************")
      end
    end

    def get_entity_builder(inventory_collection, association)
      if inventory_collection.parent && !inventory_collection.arel
        association_meta_info = inventory_collection.parent.class.reflect_on_association(inventory_collection.association)
        association_meta_info.options[:through].blank? ? association : inventory_collection.model_class
      else
        inventory_collection.model_class
      end
    end
  end
end
