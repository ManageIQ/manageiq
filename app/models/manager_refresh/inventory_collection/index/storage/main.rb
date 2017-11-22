module ManagerRefresh
  class InventoryCollection
    module Index
      class Storage::Main < ManagerRefresh::InventoryCollection::Index::Storage
        def initialize(inventory_collection, attribute_names)
          super
        end

        def find(index)
          data_index[index]
        end
      end
    end
  end
end
