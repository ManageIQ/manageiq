module ManagerRefresh::SaveCollection
  module Helper
    def save_dto_inventory(ems, dto_collection)
      _log.info("Synchronizing #{ems.name} collection #{dto_collection.size} of size #{dto_collection} to database")

      if dto_collection.custom_save_block.present?
        dto_collection.custom_save_block.call(ems, dto_collection)
      else
        _log.info("Synchronizing #{ems.name} collection #{dto_collection.size} using a custom save block")
        save_dto_inventory_multi_batch(dto_collection.parent.send(dto_collection.association),
                                       dto_collection,
                                       :use_association,
                                       dto_collection.manager_ref)
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
  end
end
