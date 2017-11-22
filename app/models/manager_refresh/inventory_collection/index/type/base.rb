module ManagerRefresh
  class InventoryCollection
    module Index
      module Type
        class Base
          include Vmdb::Logging

          def initialize(inventory_collection, attribute_names, *args)
            @data_index = {}

            @inventory_collection = inventory_collection
            @attribute_names      = attribute_names
          end

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
            data_index[inventory_object.id_with_keys(attribute_names)] = inventory_object
          end

          protected

          attr_reader :data_index, :attribute_names, :inventory_collection

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
