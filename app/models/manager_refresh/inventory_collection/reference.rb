module ManagerRefresh
  class InventoryCollection
    class Reference
      include Vmdb::Logging

      attr_reader :index_data, :ref, :stringified_reference

      def initialize(index_data, ref, keys)
        # TODO(lsmola) storing only data filtered by keys?
        @index_data = index_data
        @ref        = ref

        @stringified_reference = self.class.build_stringified_reference(index_data, keys)
      end

      def to_hash

      end

      class << self
        def from_hash

        end
      end

      class << self
        def build_stringified_reference(index_data, keys)
          if index_data.kind_of?(Hash)
            hash_index_with_keys(keys, index_data)
          else
            # TODO(lsmola) raise deprecation warning, we want to use only hash index_dataes
            _log.warn("[Deprecated] use always hash as an index, for data: #{index_data} and keys: #{keys}")
            index_data
          end
        end

        def build_stringified_reference_for_record(record, keys)
          object_index_with_keys(keys, record)
        end

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

