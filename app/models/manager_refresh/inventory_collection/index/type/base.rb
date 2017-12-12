module ManagerRefresh
  class InventoryCollection
    module Index
      module Type
        class Base
          include Vmdb::Logging

          def initialize(inventory_collection, index_name, attribute_names, *_args)
            @index = {}

            @inventory_collection = inventory_collection
            @index_name           = index_name
            @attribute_names      = attribute_names
          end

          delegate :keys, :to => :index

          def store_index_for(inventory_object)
            index[build_stringified_reference(inventory_object.data, attribute_names)] = inventory_object
          end

          def reindex!
            self.index = {}
            data.each do |inventory_object|
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

          attr_reader :attribute_names, :index, :index_name, :inventory_collection

          private

          attr_writer :index

          delegate :build_stringified_reference, :data, :to => :inventory_collection
        end
      end
    end
  end
end
