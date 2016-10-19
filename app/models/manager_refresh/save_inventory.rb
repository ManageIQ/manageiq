module ManagerRefresh
  class SaveInventory
    class << self
      def save_inventory(ems, dto_collections)
        _log.info("#{log_header(ems)} Saving EMS Inventory...Start")
        ManagerRefresh::SaveCollection::Recursive.save_collections(ems, dto_collections)
        _log.info("#{log_header(ems)} Saving EMS Inventory...Complete")
        ems
      end

      private

      def log_header(ems)
        "EMS: [#{ems.name}], id: [#{ems.id}]"
      end
    end
  end
end
