module ManagerRefresh::SaveCollection
  module Saver
    class Base
      include Vmdb::Logging

      attr_reader :inventory_collection

      def initialize(inventory_collection)
        @inventory_collection = inventory_collection
      end

      def save_inventory_collection!
        # If we have not data to save and delete is not allowed, we can just skip
        return if inventory_collection.data.blank? && !inventory_collection.delete_allowed?

        # TODO(lsmola) do I need to reload every time? Also it should be enough to clear the associations.
        inventory_collection.parent.reload if inventory_collection.parent
        association = inventory_collection.db_collection_for_comparison

        save!(inventory_collection, association)
      end
    end
  end
end
