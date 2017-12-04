module ManagerRefresh
  class InventoryCollection
    module Index
      module Type
        class Base
          include Vmdb::Logging

          def initialize(inventory_collection, attribute_names, *args)
            @index = {}

            @inventory_collection = inventory_collection
            @attribute_names      = attribute_names
          end

          delegate :keys, :to => :index

          def store_index_for(inventory_object)
            index[inventory_object.manager_uuid(attribute_names)] = inventory_object
          end

          def reindex!
            inventory_objects = index.values
            self.index = {}
            inventory_objects.each do |inventory_object|
              store_index_for(inventory_object)
            end
          end

          # Find value based on index_value
          #
          # @param _index_value [String] a index_value of the InventoryObject we search for
          def find(_index_value)
            raise "Implement in subclass"
          end

          protected

          attr_reader :index, :attribute_names, :inventory_collection

          private

          attr_writer :index
        end
      end
    end
  end
end
