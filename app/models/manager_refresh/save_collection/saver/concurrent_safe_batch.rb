module ManagerRefresh::SaveCollection
  module Saver
    class ConcurrentSafeBatch < ManagerRefresh::SaveCollection::Saver::Base
      private

      def save!(_inventory_collection, _association)
        raise "saver_strategy :concurent_safe_batch is not implemented"
      end
    end
  end
end
