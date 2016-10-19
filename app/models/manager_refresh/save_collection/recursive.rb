module ManagerRefresh::SaveCollection
  class Recursive
    extend EmsRefresh::SaveInventoryHelper
    extend ManagerRefresh::SaveCollection::Helper

    class << self
      def save_collections(ems, dto_collections)
        dto_collections.each do |_key, dto_collection|
          save_collection(ems, dto_collection, [])
        end
      end

      private

      def save_collection(ems, dto_collection, traversed_collections)
        unless dto_collection.kind_of? ::ManagerRefresh::DtoCollection
          raise "A ManagerRefresh::SaveInventory needs a DtoCollection object, it got: #{dto_collection.inspect}"
        end

        return if dto_collection.saved?

        traversed_collections << dto_collection

        unless dto_collection.saveable?
          dto_collection.dependencies.each do |dependency|
            if traversed_collections.include? dependency
              raise "Edge from #{dto_collection} to #{dependency} creates a cycle"
            end
            save_collection(ems, dependency, traversed_collections)
          end
        end

        save_dto_inventory(ems, dto_collection)
      end
    end
  end
end
