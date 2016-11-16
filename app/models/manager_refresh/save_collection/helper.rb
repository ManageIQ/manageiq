module ManagerRefresh::SaveCollection
  module Helper
    def save_dto_inventory(ems, dto_collection)
      _log.info("Synchronizing #{ems.name} collection #{dto_collection.size} of size #{dto_collection} to database")

      if dto_collection.custom_save_block.present?
        _log.info("Synchronizing #{ems.name} collection #{dto_collection.size} using a custom save block")
        dto_collection.custom_save_block.call(ems, dto_collection)
      else
        save_inventory(dto_collection)
      end
      _log.info("Synchronized #{ems.name} collection #{dto_collection}")
      dto_collection.saved = true
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

    def save_inventory(dto_collection)
      dto_collection.parent.reload
      association  = dto_collection.parent.send(dto_collection.association)
      record_index = {}

      create_or_update_inventory!(dto_collection, record_index, association)
      # TODO(lsmola) delete only if DtoCollection is complete?
      delete_inventory!(dto_collection, record_index, association)
    end

    def create_or_update_inventory!(dto_collection, record_index, association)
      unique_index_keys = dto_collection.manager_ref_to_cols

      association.find_each do |record|
        # TODO(lsmola) the old code was able to deal with duplicate records, should we do that? The old data still can
        # have duplicate methods, so we should clean them up. It will slow up the indexing though.
        record_index[dto_collection.object_index_with_keys(unique_index_keys, record)] = record
      end

      association_meta_info = dto_collection.parent.class.reflect_on_association(dto_collection.association)
      entity_builder        = association_meta_info.options[:through].blank? ? association : dto_collection.model_class

      dto_collection_size = dto_collection.size
      created_counter     = 0
      _log.info("*************** PROCESSING #{dto_collection} of size #{dto_collection_size} ***************")
      ActiveRecord::Base.transaction do
        dto_collection.each do |dto|
          hash       = dto.attributes(dto_collection)
          dto.object = record_index.delete(dto.manager_uuid)
          if dto.object.nil?
            dto.object      = entity_builder.create!(hash.except(:id))
            created_counter += 1
          else
            dto.object.assign_attributes(hash.except(:id, :type))
            if dto.object.changed?
              dto.object.save!
            end
          end
          dto.object.send(:clear_association_cache)
        end
      end
      _log.info("*************** PROCESSED #{dto_collection}, created=#{created_counter}, "\
                "updated=#{dto_collection_size - created_counter} ***************")
    end

    def delete_inventory!(dto_collection, record_index, association)
      # Delete the items no longer found
      unless record_index.blank?
        deletes = record_index.values
        _log.info("*************** DELETING #{dto_collection} of size #{deletes.size} ***************")
        type = association.proxy_association.reflection.name
        _log.info("[#{type}] Deleting with method '#{dto_collection.delete_method}' #{log_format_deletes(deletes)}")
        ActiveRecord::Base.transaction do
          deletes.map(&dto_collection.delete_method)
        end
        _log.info("*************** DELETED #{dto_collection} ***************")
      end
    end
  end
end
