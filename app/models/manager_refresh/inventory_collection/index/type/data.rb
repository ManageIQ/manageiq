module ManagerRefresh
  class InventoryCollection
    module Index
      module Type
        class Data < ManagerRefresh::InventoryCollection::Index::Type::Base
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
end
