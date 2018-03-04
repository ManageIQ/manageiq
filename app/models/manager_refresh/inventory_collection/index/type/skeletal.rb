module ManagerRefresh
  class InventoryCollection
    module Index
      module Type
        class Skeletal < ManagerRefresh::InventoryCollection::Index::Type::Base
          # (see ManagerRefresh::InventoryCollection::Index::Type::Base#initialize)
          # @param primary_index [ManagerRefresh::InventoryCollection::Index::Type::Data] Data index of primary_index
          def initialize(inventory_collection, index_name, attribute_names, primary_index)
            super

            @primary_index = primary_index
          end

          delegate :builder_params,
                   :new_inventory_object,
                   :named_ref,
                   :to => :inventory_collection

          delegate :blank?,
                   :each,
                   :to => :index

          # Find value based on index_value
          #
          # @param index_value [String] a index_value of the InventoryObject we search for
          # @return [InventoryObject|nil] Returns found value or nil
          def find(index_value)
            index[index_value]
          end

          # Deletes and returns the value on the index_value
          #
          # @param index_value [String] a index_value of the InventoryObject we search for
          # @return [InventoryObject|nil] Returns found value or nil
          def delete(index_value)
            index.delete(index_value)
          end

          # Builds index record with skeletal InventoryObject and returns it, or returns nil if it's already present
          # in primary_index or skeletal_primary_index
          #
          # @param attributes [Hash] Skeletal data of the index, must contain unique index keys and everything else
          #        needed for creating the record in the Database
          # @return [InventoryObject|nil] Returns built value or nil
          def build(attributes)
            attributes = {}.merge!(builder_params).merge!(attributes)

            # If the primary index is already filled, we don't want populate skeletal index
            uuid = ::ManagerRefresh::InventoryCollection::Reference.build_stringified_reference(attributes, named_ref)
            return if primary_index.find(uuid)

            # Return if skeletal index already exists
            return if index[uuid]

            # We want to populate a new skeletal index
            inventory_object                     = new_inventory_object(attributes)
            index[inventory_object.manager_uuid] = inventory_object
          end

          private

          attr_reader :primary_index
        end
      end
    end
  end
end
