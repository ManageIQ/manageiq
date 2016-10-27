module ManagerRefresh
  class SaveInventory
    class << self
      def save_inventory(ems, dto_collections)
        _log.info("#{log_header(ems)} Saving EMS Inventory...Start")

        dto_saving_strategy = Settings.ems_refresh[ems.class.ems_type].try(:[], :dto_saving_strategy)
        if dto_saving_strategy == :recursive
          ManagerRefresh::SaveCollection::Recursive.save_collections(ems, dto_collections)
        else
          ManagerRefresh::SaveCollection::TopologicalSort.save_collections(ems, dto_collections)
        end

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
