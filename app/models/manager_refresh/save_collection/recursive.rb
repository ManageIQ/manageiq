module ManagerRefresh::SaveCollection
  class Recursive
    extend EmsRefresh::SaveInventoryHelper
    extend ManagerRefresh::SaveCollection::Helper

    class << self
      def save_collections(dto_collections)
        dto_collections.each do |_key, dto_collection|
          save_collection(dto_collection, [])
        end
      end

      private

      def save_collection(dto_collection, traversed_collections)
        unless dto_collection.is_a? ::ManagerRefresh::DtoCollection
          raise "A ManagerRefresh::SaveInventory needs a DtoCollection object, it got: #{dto_collection.inspect}"
        end

        return if dto_collection.saved?

        traversed_collections << dto_collection

        if dto_collection.saveable?
          save_dto_inventory(dto_collection)
        else
          dto_collection.dependencies.each do |dependency|
            if traversed_collections.include? dependency
              raise "Edge from #{dto_collection} to #{dependency} creates a cycle"
            end
            save_collection(dependency, traversed_collections)
          end

          save_dto_inventory(dto_collection)
        end
      end
    end
  end
end
