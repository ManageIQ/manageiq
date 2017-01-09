module ManagerRefresh
  class SaveInventory
    class << self
      def save_inventory(ems, inventory_collections)
        _log.info("#{log_header(ems)} Saving EMS Inventory...Start")

        inventory_object_saving_strategy = Settings.ems_refresh[ems.class.ems_type].try(:[], :inventory_object_saving_strategy)
        if inventory_object_saving_strategy == :recursive
          ManagerRefresh::SaveCollection::Recursive.save_collections(ems, inventory_collections)
        else
          ManagerRefresh::SaveCollection::TopologicalSort.save_collections(ems, inventory_collections)
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
