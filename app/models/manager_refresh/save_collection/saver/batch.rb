module ManagerRefresh::SaveCollection
  module Saver
    class Batch < ManagerRefresh::SaveCollection::Saver::ConcurrentSafeBatch
      private

      def unique_index_columns
        inventory_collection.manager_ref_to_cols.map(&:to_sym)
      end

      def on_conflict_update
        false
      end
    end
  end
end
