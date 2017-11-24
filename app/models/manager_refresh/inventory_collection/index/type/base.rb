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

          # TODO(lsmola) we should not need this as public, it's used by lazy_find method only.
          def object_index(object)
            if object.kind_of?(String) || object.kind_of?(Integer)
              object
            elsif object.respond_to?(:[])
              hash_index_with_keys(attribute_names, object)
            else
              object_index_with_keys(attribute_names, object)
            end
          end

          def store_index_for(inventory_object)
            index[inventory_object.manager_uuid(attribute_names)] = inventory_object
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

          def hash_index_with_keys(keys, hash)
            stringify_reference(keys.map { |attribute| hash[attribute].to_s })
          end

          def object_index_with_keys(keys, object)
            stringify_reference(keys.map { |attribute| object.public_send(attribute).to_s })
          end

          def stringify_joiner
            "__"
          end

          def stringify_reference(reference)
            reference.join(stringify_joiner)
          end
        end
      end
    end
  end
end
