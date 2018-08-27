module ManagerRefresh
  class InventoryCollection
    class Serialization
      delegate :all_manager_uuids,
               :build,
               :targeted_scope,
               :data,
               :inventory_object_lazy?,
               :inventory_object?,
               :name,
               :skeletal_primary_index,
               :to => :inventory_collection

      attr_reader :inventory_collection

      # @param inventory_collection [ManagerRefresh::InventoryCollection] InventoryCollection object we want the storage
      #        for
      def initialize(inventory_collection)
        @inventory_collection = inventory_collection
      end

      # Loads InventoryCollection data from it's serialized form into existing InventoryCollection object
      #
      # @param inventory_objects_data [Hash] Serialized InventoryCollection as Hash
      # @param available_inventory_collections [Array<ManagerRefresh::InventoryCollection>] List of available
      #        InventoryCollection objects
      def from_hash(inventory_objects_data, available_inventory_collections)
        targeted_scope.merge!(inventory_objects_data["manager_uuids"].map(&:symbolize_keys!))

        inventory_objects_data['data'].each do |inventory_object_data|
          build(hash_to_data(inventory_object_data, available_inventory_collections).symbolize_keys!)
        end

        inventory_objects_data['partial_data'].each do |inventory_object_data|
          skeletal_primary_index.build(hash_to_data(inventory_object_data, available_inventory_collections).symbolize_keys!)
        end

        # TODO(lsmola) add support for all_manager_uuids serialization
        # self.all_manager_uuids = inventory_objects_data['all_manager_uuids']
      end

      # Serializes InventoryCollection's data storage into Array of Hashes
      #
      # @return [Hash] Serialized InventoryCollection object into Hash
      def to_hash
        {
          :name              => name,
          # TODO(lsmola) we do not support nested references here, should we?
          :manager_uuids     => targeted_scope.primary_references.values.map(&:full_reference),
          :all_manager_uuids => all_manager_uuids,
          :data              => data.map { |x| data_to_hash(x.data) },
          :partial_data      => skeletal_primary_index.index_data.map { |x| data_to_hash(x.data) },
        }
      end

      private

      # Converts ManagerRefresh::InventoryObject or ManagerRefresh::InventoryObjectLazy into Hash
      #
      # @param value [ManagerRefresh::InventoryObject, ManagerRefresh::InventoryObjectLazy] InventoryObject or a lazy link
      # @param depth [Integer] Depth of nesting for nested lazy link
      # @return [Hash] Serialized ManagerRefresh::InventoryObjectLazy
      def lazy_relation_to_hash(value, depth = 0)
        {
          :type                        => "ManagerRefresh::InventoryObjectLazy",
          :inventory_collection_name   => value.inventory_collection.name,
          :reference                   => data_to_hash(value.reference.full_reference, depth + 1),
          :ref                         => value.reference.ref,
          :key                         => value.try(:key),
          :default                     => value.try(:default),
          :transform_nested_lazy_finds => value.try(:transform_nested_lazy_finds)
        }
      end

      # Converts Hash to ManagerRefresh::InventoryObjectLazy
      #
      # @param value [Hash] Serialized InventoryObject or a lazy link
      # @param available_inventory_collections [Array<ManagerRefresh::InventoryCollection>] List of available
      #        InventoryCollection objects
      # @param depth [Integer] Depth of nesting for nested lazy link
      # @return [ManagerRefresh::InventoryObjectLazy] Lazy link created from hash
      def hash_to_lazy_relation(value, available_inventory_collections, depth = 0)
        inventory_collection = available_inventory_collections[value['inventory_collection_name'].try(:to_sym)]
        raise "Couldn't build lazy_link #{value} the inventory_collection_name was not found" if inventory_collection.blank?

        inventory_collection.lazy_find(
          hash_to_data(value['reference'], available_inventory_collections, depth + 1).symbolize_keys!,
          :ref                         => value['ref'].try(:to_sym),
          :key                         => value['key'].try(:to_sym),
          :default                     => value['default'],
          :transform_nested_lazy_finds => value['transform_nested_lazy_finds']
        )
      end

      # Converts Hash to attributes usable for building InventoryObject
      #
      # @param hash [Hash] Serialized InventoryObject data
      # @param available_inventory_collections [Array<ManagerRefresh::InventoryCollection>] List of available
      #        InventoryCollection objects
      # @param depth [Integer] Depth of nesting for nested lazy link
      # @return [Hash] Hash with data usable for building InventoryObject
      def hash_to_data(hash, available_inventory_collections, depth = 0)
        raise "Nested lazy_relation of #{inventory_collection} is too deep, left processing: #{hash}" if depth > 20

        hash.transform_values do |value|
          if value.kind_of?(Hash) && value['type'] == "ManagerRefresh::InventoryObjectLazy"
            hash_to_lazy_relation(value, available_inventory_collections, depth)
          elsif value.kind_of?(Array) && value.first.kind_of?(Hash) && value.first['type'] == "ManagerRefresh::InventoryObjectLazy"
            # TODO(lsmola) do we need to compact it sooner? What if first element is nil? On the other hand, we want to
            # deprecate this Vm HABTM assignment because it's not effective
            value.compact.map { |x| hash_to_lazy_relation(x, available_inventory_collections, depth) }
          else
            value
          end
        end
      end

      # Transforms data of the InventoryObject or Reference to InventoryObject into Hash
      #
      # @param data [Hash] Data of the InventoryObject or Reference to InventoryObject
      # @param depth [Integer] Depth of nesting for nested lazy link
      # @return [Hash] Serialized InventoryObject or Reference data into Hash
      def data_to_hash(data, depth = 0)
        raise "Nested lazy_relation of #{inventory_collection} is too deep, left processing: #{data}" if depth > 20

        data.transform_values do |value|
          if inventory_object_lazy?(value) || inventory_object?(value)
            lazy_relation_to_hash(value, depth)
          elsif value.kind_of?(Array) && (inventory_object_lazy?(value.compact.first) || inventory_object?(value.compact.first))
            value.compact.map { |x| lazy_relation_to_hash(x, depth) }
          else
            value
          end
        end
      end
    end
  end
end
