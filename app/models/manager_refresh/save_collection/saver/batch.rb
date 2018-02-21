module ManagerRefresh::SaveCollection
  module Saver
    class Batch < ManagerRefresh::SaveCollection::Saver::ConcurrentSafeBatch
      private

      # Just returning manager ref transformed to column names, for strategies that do not expect to have unique DB
      # indexes.
      #
      # @return [Array<Symbol>] manager ref transformed to column names
      def unique_index_columns
        inventory_collection.manager_ref_to_cols.map(&:to_sym)
      end
    end
  end
end
