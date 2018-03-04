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

      delegate :builder_params,
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

      # Returns array of built InventoryObject objects
      #
      # @return [Array<ManagerRefresh::InventoryObject>] Array of built InventoryObject objects
      def to_a
        data
      end

      # Reconstructs InventoryCollection from it's serialized form
      #
      # @param inventory_objects_data [Array[Hash]] Serialized array of InventoryObject objects as hashes
      # @param available_inventory_collections [Array<ManagerRefresh::InventoryCollection>] List of available
      #        InventoryCollection objects
      def from_raw_data(inventory_objects_data, available_inventory_collections)
        inventory_objects_data.each do |inventory_object_data|
          hash = inventory_object_data.each_with_object({}) do |(key, value), result|
            result[key.to_sym] = if value.kind_of?(Array)
                                   value.map { |x| from_raw_value(x, available_inventory_collections) }
                                 else
                                   from_raw_value(value, available_inventory_collections)
                                 end
          end
          build(hash)
        end
      end

      # Transform serialized references into lazy InventoryObject objects
      #
      # @param value [Object, Hash] Serialized InventoryObject into Hash
      # @param available_inventory_collections [Array<ManagerRefresh::InventoryCollection>] List of available
      #        InventoryCollection objects
      # @return [Object, ManagerRefresh::InventoryObjectLazy] Returns ManagerRefresh::InventoryObjectLazy object
      #         if the serialized form was a reference, or return original value
      def from_raw_value(value, available_inventory_collections)
        if value.kind_of?(Hash) && (value['type'] || value[:type]) == "ManagerRefresh::InventoryObjectLazy"
          value.transform_keys!(&:to_s)
        end

        if value.kind_of?(Hash) && value['type'] == "ManagerRefresh::InventoryObjectLazy"
          inventory_collection = available_inventory_collections[value['inventory_collection_name'].try(:to_sym)]
          raise "Couldn't build lazy_link #{value} the inventory_collection_name was not found" if inventory_collection.blank?
          inventory_collection.lazy_find(value['ems_ref'], :key => value['key'], :default => value['default'])
        else
          value
        end
      end

      # Serializes InventoryCollection's data storage into Array of Hashes, which we can turn into JSON or YAML
      #
      # @return [Array<Hash>] Serialized InventoryCollection's data storage
      def to_raw_data
        data.map do |inventory_object|
          inventory_object.data.transform_values do |value|
            if inventory_object_lazy?(value)
              value.to_raw_lazy_relation
            elsif value.kind_of?(Array) && (inventory_object_lazy?(value.compact.first) || inventory_object?(value.compact.first))
              value.compact.map(&:to_raw_lazy_relation)
            elsif inventory_object?(value)
              value.to_raw_lazy_relation
            else
              value
            end
          end
        end
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

        if manager_ref.any? { |x| !hash.key?(x) }
          raise "Needed find_or_build_by keys are: #{manager_ref}, data provided: #{hash}"
        end

        uuid = ::ManagerRefresh::InventoryCollection::Reference.build_stringified_reference(hash, named_ref)
        return hash, uuid, primary_index.find(uuid)
      end

      # Returns new hash enriched by (see ManagerRefresh::InventoryCollection#builder_params) hash
      #
      # @param hash [Hash] Input hash
      # @return [Hash] Enriched hash by (see ManagerRefresh::InventoryCollection#builder_params)
      def enrich_data(hash)
        # This is 25% faster than builder_params.merge(hash)
        {}.merge!(builder_params).merge!(hash)
      end
    end
  end
end
