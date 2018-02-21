module ManagerRefresh
  class InventoryCollection
    class Reference
      include Vmdb::Logging

      attr_reader :full_reference, :keys, :ref, :stringified_reference

      delegate :[], :to => :full_reference

      # @param data [Hash, String] Data needed for creating the reference
      # @param ref [String] Name of the reference (and of the index associated)
      # @param keys [Array<Symbol>] Attribute/column names of the reference, that are used as indexes of the passed
      #        data hash
      def initialize(data, ref, keys)
        @full_reference = build_full_reference(data, keys)
        @ref            = ref
        @keys           = keys

        @stringified_reference = self.class.build_stringified_reference(full_reference, keys)
      end

      # Return true if reference is to primary index, false otherwise.
      #
      # @return [Boolean] true if reference is to primary index, false otherwise
      def primary?
        ref == :manager_ref
      end

      # Returns serialized self into Hash
      #
      # @return [Hash] Serialized self into Hash
      def to_hash
      end

      class << self
        # Returns reference object built from serialized Hash
        #
        # @return [ManagerRefresh::InventoryCollection::Reference] Reference object built from serialized Hash
        def from_hash
        end
      end

      class << self
        # Builds string uuid from passed Hash and keys
        #
        # @param hash [Hash] Hash data
        # @param keys [Array<Symbol>] Indexes into the Hash data
        # @return [String] Concatenated values on keys from data
        def build_stringified_reference(hash, keys)
          stringify_reference(keys.map { |attribute| hash[attribute].to_s })
        end

        # Builds string uuid from passed Object and keys
        #
        # @param record [ApplicationRecord] ActiveRecord record
        # @param keys [Array<Symbol>] Indexes into the Hash data
        # @return [String] Concatenated values on keys from data
        def build_stringified_reference_for_record(record, keys)
          stringify_reference(keys.map { |attribute| record.public_send(attribute).to_s })
        end

        # Returns passed array joined by stringify_joiner
        #
        # @param reference [Array<String>]
        # @return [String] Passed array joined by stringify_joiner
        def stringify_reference(reference)
          reference.join(stringify_joiner)
        end

        private

        # Returns joiner for string UIID
        #
        # @return [String] Joiner for stirng UIID
        def stringify_joiner
          "__"
        end
      end

      private

      # Returns original Hash, or build hash out of passed string
      #
      # @param data [Hash, String] Passed data
      # @param keys [Array<Symbol>] Keys for the reference
      # @return [Hash] Original Hash, or build hash out of passed string
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
