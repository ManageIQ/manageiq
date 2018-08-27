module ManagerRefresh
  class InventoryCollection
    class DataStorage
      include Vmdb::Logging

      # @return [Array<InventoryObject>] objects of the InventoryCollection in an Array
      attr_accessor :data

      attr_reader :index_proxy, :inventory_collection

      delegate :each, :size, :to => :data

      delegate :primary_index,
               :build_primary_index_for,
               :build_secondary_indexes_for,
               :named_ref,
               :skeletal_primary_index,
               :to => :index_proxy

      delegate :association_to_foreign_key_mapping,
               :default_values,
               :inventory_object?,
               :inventory_object_lazy?,
               :manager_ref,
               :new_inventory_object,
               :to => :inventory_collection

      # @param inventory_collection [ManagerRefresh::InventoryCollection] InventoryCollection object we want the storage
      #        for
      # @param secondary_refs [Hash] Secondary_refs in format {:name_of_the_ref => [:attribute1, :attribute2]}
      def initialize(inventory_collection, secondary_refs)
        @inventory_collection = inventory_collection
        @data                 = []

        @index_proxy = ManagerRefresh::InventoryCollection::Index::Proxy.new(inventory_collection, secondary_refs)
      end

      # Adds passed InventoryObject into the InventoryCollection's storage
      #
      # @param inventory_object [ManagerRefresh::InventoryObject]
      # @return [ManagerRefresh::InventoryCollection] Returns current InventoryCollection, to allow chaining
      def <<(inventory_object)
        if inventory_object.manager_uuid.present? && !primary_index.find(inventory_object.manager_uuid)
          data << inventory_object

          # TODO(lsmola) Maybe we do not need the secondary indexes here?
          # Maybe we should index it like LocalDb indexes, on demand, and storing what was
          # indexed? Maybe we should allow only lazy access and no direct find from a parser. Since for streaming
          # refresh, things won't be parsed together and no full state will be taken.
          build_primary_index_for(inventory_object)
          build_secondary_indexes_for(inventory_object)
        end
        inventory_collection
      end

      alias push <<

      # Finds of builds a new InventoryObject. By building it, we also put in into the InventoryCollection's storage.
      #
      # @param manager_uuid [String] manager_uuid of the InventoryObject
      # @return [ManagerRefresh::InventoryObject] Found or built InventoryObject
      def find_or_build(manager_uuid)
        raise "The uuid consists of #{manager_ref.size} attributes, please find_or_build_by method" if manager_ref.size > 1

        find_or_build_by(manager_ref.first => manager_uuid)
      end

      # (see #build)
      def find_or_build_by(hash)
        build(hash)
      end

      # Finds InventoryObject.
      #
      # @param hash [Hash] Hash that needs to contain attributes defined in :manager_ref of the InventoryCollection
      # @return [ManagerRefresh::InventoryObject] Found or built InventoryObject object
      def find_in_data(hash)
        _hash, _uuid, inventory_object = primary_index_scan(hash)
        inventory_object
      end

      # Finds of builds a new InventoryObject. By building it, we also put in into the InventoryCollection's storage.
      #
      # @param hash [Hash] Hash that needs to contain attributes defined in :manager_ref of the
      #        InventoryCollection
      # @return [ManagerRefresh::InventoryObject] Found or built InventoryObject object
      def build(hash)
        hash, uuid, inventory_object = primary_index_scan(hash)

        # Return InventoryObject if found in primary index
        return inventory_object unless inventory_object.nil?

        # We will take existing skeletal record, so we don't duplicate references for saving. We can have duplicated
        # reference from local_db index, (if we are using .find in parser, that causes N+1 db queries), but that is ok,
        # since that one is not being saved.
        inventory_object = skeletal_primary_index.delete(uuid)

        # We want to update the skeletal record with actual data
        inventory_object&.assign_attributes(hash)

        # Build the InventoryObject
        inventory_object ||= new_inventory_object(enrich_data(hash))

        # Store new InventoryObject and return it
        push(inventory_object)
        inventory_object
      end

      # Finds of builds a new InventoryObject with incomplete data.
      #
      # @param hash [Hash] Hash that needs to contain attributes defined in :manager_ref of the
      #        InventoryCollection
      # @return [ManagerRefresh::InventoryObject] Found or built InventoryObject object
      def build_partial(hash)
        skeletal_primary_index.build(hash)
      end

      # Returns array of built InventoryObject objects
      #
      # @return [Array<ManagerRefresh::InventoryObject>] Array of built InventoryObject objects
      def to_a
        data
      end

      def to_hash
        ManagerRefresh::InventoryCollection::Serialization.new(inventory_collection).to_hash
      end

      def from_hash(inventory_objects_data, available_inventory_collections)
        ManagerRefresh::InventoryCollection::Serialization
          .new(inventory_collection)
          .from_hash(inventory_objects_data, available_inventory_collections)
      end

      private

      # Scans primary index for existing InventoryObject, that would be equivalent to passed hash. It also returns
      # enriched data and uuid, so we do not have to compute it multiple times.
      #
      # @param hash [Hash] Attributes for the InventoryObject
      # @return [Array(Hash, String, ManagerRefresh::InventoryObject)] Returns enriched data, uuid and InventoryObject
      # if found (otherwise nil)
      def primary_index_scan(hash)
        hash = enrich_data(hash)

        assert_all_keys_present(hash)
        assert_only_primary_index(hash)

        uuid = ::ManagerRefresh::InventoryCollection::Reference.build_stringified_reference(hash, named_ref)
        return hash, uuid, primary_index.find(uuid)
      end

      def assert_all_keys_present(hash)
        if manager_ref.any? { |x| !hash.key?(x) }
          raise "Needed find_or_build_by keys are: #{manager_ref}, data provided: #{hash}"
        end
      end

      def assert_only_primary_index(data)
        named_ref.each do |key|
          if data[key].kind_of?(ManagerRefresh::InventoryObjectLazy) && !data[key].primary?
            raise "Wrong index for key :#{key}, all references under this index must point to default :ref called"\
                  " :manager_ref. Any other :ref is not valid. This applies also to nested lazy links."
          end
        end
      end

      # Returns new hash enriched by (see ManagerRefresh::InventoryCollection#default_values) hash
      #
      # @param hash [Hash] Input hash
      # @return [Hash] Enriched hash by (see ManagerRefresh::InventoryCollection#default_values)
      def enrich_data(hash)
        # This is 25% faster than default_values.merge(hash)
        {}.merge!(default_values).merge!(hash)
      end
    end
  end
end
