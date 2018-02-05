module ManagerRefresh
  class InventoryCollection
    class Reference
      include Vmdb::Logging

      attr_reader :full_reference, :ref, :stringified_reference

      delegate :[], :to => :full_reference

      def initialize(data, ref, keys)
        @full_reference = build_full_reference(data, keys)
        @ref            = ref

        @stringified_reference = self.class.build_stringified_reference(full_reference, keys)
      end

      def to_hash
      end

      class << self
        def from_hash
        end
      end

      class << self
        def build_stringified_reference(data, keys)
          hash_index_with_keys(keys, data)
        end

        def build_stringified_reference_for_record(record, keys)
          object_index_with_keys(keys, record)
        end

        def stringify_reference(reference)
          reference.join(stringify_joiner)
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
      end

      private

      def build_full_reference(data, keys)
        if data.kind_of?(Hash)
          data
        else
          # assert_index makes sure that only keys of size 1 can go here
          {keys.first => data}
        end
      end
    end
  end
end
