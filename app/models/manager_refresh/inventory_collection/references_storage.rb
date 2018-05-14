module ManagerRefresh
  class InventoryCollection
    class ReferencesStorage
      # @return [Hash] A set of InventoryObjects manager_uuids, which tells us which InventoryObjects were
      #         referenced by other InventoryObjects using a lazy_find.
      attr_reader :references

      # @return [Set] A set of InventoryObject attributes names, which tells us InventoryObject attributes
      #         were referenced by other InventoryObject objects using a lazy_find with :key.
      attr_reader :attribute_references

      def initialize(index_proxy)
        @index_proxy                   = index_proxy
        @references                    = {}
        @references[primary_index_ref] = {}
        @attribute_references          = Set.new
      end

      # Adds reference to the storage. The reference can be already existing, otherwise we attempt to build it.
      #
      # @param reference_data [ManagerRefresh::InventoryCollection::References, Hash, Object] Either existing Reference
      #        object, or data we will build the reference object from. For InventoryCollection with :manager_ref size
      #        bigger than 1, it's required to pass a Hash.
      # @param key [String] If the reference comes from a InventoryObjectLazy, pointing to specific attribute using :key
      #        we want to record what attribute was referenced.
      # @param ref [Symbol] A key to specific reference, if it's a reference pointing to something else than primary
      #        index.
      def add_reference(reference_data, key: nil, ref: nil)
        reference           = build_reference(reference_data, ref)
        specific_references = references[reference.ref] ||= {}

        specific_references[reference.stringified_reference] = reference

        # If we access an attribute of the value, using a :key, we want to keep a track of that
        attribute_references << key if key
      end

      # Adds reference to the storage. The reference can be already existing, otherwise we attempt to build it. This is
      # simplified version of add_reference, not allowing to define :key or :ref.
      #
      # @param reference_data [ManagerRefresh::InventoryCollection::References, Hash, Object] Either existing Reference
      #        object, or data we will build the reference object from. For InventoryCollection with :manager_ref size
      #        bigger than 1, it's required to pass a Hash.
      def <<(reference_data)
        add_reference(reference_data)
      end

      # Adds array of references to the storage. The reference can be already existing, otherwise we attempt to build
      # it.
      #
      # @param references_array [Array] Array of reference objects acceptable by add_reference method.
      # @param ref [Symbol] A key to specific reference, if it's a reference pointing to something else than primary
      #        index.
      # @return [ManagerRefresh::InventoryCollection::ReferencesStorage] Returns self
      def merge!(references_array, ref: nil)
        references_array.each { |reference_data| add_reference(reference_data, :ref => ref) }
        self
      end

      # @return [Hash{String => ManagerRefresh::InventoryCollection::Reference}] Hash of indexed Reference objects
      def primary_references
        references[primary_index_ref]
      end

      # Builds a Reference object
      #
      # @param reference_data [ManagerRefresh::InventoryCollection::References, Hash, Object] Either existing Reference
      #        object, or data we will build the reference object from. For InventoryCollection with :manager_ref size
      #        bigger than 1, it's required to pass a Hash.
      def build_reference(reference_data, ref = nil)
        ref ||= primary_index_ref
        return reference_data if reference_data.kind_of?(::ManagerRefresh::InventoryCollection::Reference)

        ::ManagerRefresh::InventoryCollection::Reference.new(reference_data, ref, named_ref(ref))
      end

      # Builds string uuid from passed Hash and keys
      #
      # @param hash [Hash] Hash data
      # @param keys [Array<Symbol>] Indexes into the Hash data
      # @return [String] Concatenated values on keys from data
      def build_stringified_reference(hash, keys)
        ::ManagerRefresh::InventoryCollection::Reference.build_stringified_reference(hash, keys)
      end

      # Builds string uuid from passed Object and keys
      #
      # @param record [ApplicationRecord] ActiveRecord record
      # @param keys [Array<Symbol>] Indexes into the Hash data
      # @return [String] Concatenated values on keys from data
      def build_stringified_reference_for_record(record, keys)
        ::ManagerRefresh::InventoryCollection::Reference.build_stringified_reference_for_record(record, keys)
      end

      private

      # @return [ManagerRefresh::InventoryCollection::Index::Proxy] Index::Proxy object associated to this reference
      #         storage
      attr_reader :index_proxy

      delegate :named_ref,
               :primary_index_ref,
               :to => :index_proxy
    end
  end
end
