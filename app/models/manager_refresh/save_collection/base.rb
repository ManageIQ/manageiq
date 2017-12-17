module ManagerRefresh::SaveCollection
  class Base
    class << self
      def save_inventory_object_inventory(ems, inventory_collection)
        _log.debug("Saving collection #{inventory_collection} of size #{inventory_collection.size} to"\
                   " the database, for the manager: '#{ems.name}'...")

        if inventory_collection.custom_save_block.present?
          _log.debug("Saving collection #{inventory_collection} using a custom save block")
          inventory_collection.custom_save_block.call(ems, inventory_collection)
        else
          save_inventory(inventory_collection)
        end
        _log.debug("Saving collection #{inventory_collection}, for the manager: '#{ems.name}'...Complete")
        inventory_collection.saved = true
      end

      private

      def save_inventory(inventory_collection)
        saver_class = "ManagerRefresh::SaveCollection::Saver::#{inventory_collection.saver_strategy.to_s.camelize}"
        saver_class.constantize.new(inventory_collection).save_inventory_collection!
      end
    end
  end
end
