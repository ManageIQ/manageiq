module ManagerRefresh
  class InventoryCollection
    class ReferencesStorage
      # @return [Set] A set of InventoryObjects manager_uuids, which tells us which InventoryObjects were
      #         referenced by other InventoryObjects using a lazy_find.
      attr_reader :references

      # @return [Set] A set of InventoryObject attributes names, which tells us InventoryObject attributes
      #         were referenced by other InventoryObject objects using a lazy_find with :key.
      attr_reader :attribute_references

      attr_reader :index_proxy

      def initialize(index_proxy)
        @index_proxy          = index_proxy
        @references           = {}
        @attribute_references = Set.new
      end

      def add_reference(reference, key: nil)
        (references[reference.ref] ||= {})[reference.stringified_reference] = reference unless references[reference.stringified_reference]

        # If we access an attribute of the value, using a :key, we want to keep a track of that
        attribute_references << key if key
      end

      def build_reference(index_data, ref = :manager_ref)
        return index_data if index_data.kind_of? ::ManagerRefresh::InventoryCollection::Reference

        ::ManagerRefresh::InventoryCollection::Reference.new(index_data, ref, named_ref(ref))
      end

      def build_stringified_reference(index_data, keys)
        ::ManagerRefresh::InventoryCollection::Reference.build_stringified_reference(index_data, keys)
      end

      def build_stringified_reference_for_record(record, keys)
        ::ManagerRefresh::InventoryCollection::Reference.build_stringified_reference_for_record(record, keys)
      end

      private

      delegate :named_ref, :to => :index_proxy
    end
  end
end
