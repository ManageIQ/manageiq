module ManagerRefresh
  class SaveInventory
    extend EmsRefresh::SaveInventoryHelper

    class << self
      def save_inventory(ems, hashes)
        _log.info("#{log_header(ems)} Saving EMS Inventory...Start")

        hashes.each do |_key, dto_collection|
          save_collection(dto_collection)
        end

        _log.info("#{log_header(ems)} Saving EMS Inventory...Complete")
        ems
      end

      def save_collection(dto_collection)
        unless dto_collection.is_a? ::DtoCollection
          raise "A ManagerRefresh::SaveInventory needs a DtoCollection object, it got: #{dto_collection.inspect}"
        end

        return if dto_collection.saved?

        if dto_collection.saveable?
          save_dto_inventory(dto_collection)
        else
          dto_collection.dependencies.each do |dependency|
            save_collection(dependency)
          end

          save_dto_inventory(dto_collection)
        end
      end

      private
      def save_dto_inventory(dto_collection)
        save_dto_inventory_multi(dto_collection.parent.send(dto_collection.association),
                                 dto_collection,
                                 :use_association,
                                 dto_collection.manager_ref)
        store_ids_for_new_dto_records(dto_collection.parent.send(dto_collection.association),
                                      dto_collection,
                                      dto_collection.manager_ref)
        dto_collection.saved = true
      end

      def log_header(ems)
        "EMS: [#{ems.name}], id: [#{ems.id}]"
      end
    end
  end
end
