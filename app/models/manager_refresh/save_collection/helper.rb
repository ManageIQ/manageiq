module ManagerRefresh::SaveCollection
  module Helper
    def save_dto_inventory(ems, dto_collection)
      dto_batch_saving = Settings.ems_refresh[ems.class.ems_type].try(:[], :dto_batch_saving)
      if dto_batch_saving
        save_dto_inventory_multi_batch(dto_collection.parent.send(dto_collection.association),
                                       dto_collection,
                                       :use_association,
                                       dto_collection.manager_ref)
      else
        save_dto_inventory_multi(dto_collection.parent.send(dto_collection.association),
                                 dto_collection,
                                 :use_association,
                                 dto_collection.manager_ref)
      end
      store_ids_for_new_dto_records(dto_collection.parent.send(dto_collection.association),
                                    dto_collection)
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
