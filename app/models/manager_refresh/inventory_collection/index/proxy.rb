module ManagerRefresh
  class InventoryCollection
    module Index
      class Proxy
        include Vmdb::Logging

        attr_reader :skeletal_primary_index

        # @param inventory_collection [ManagerRefresh::InventoryCollection] InventoryCollection object owning the proxy
        # @param secondary_refs [Hash] Secondary_refs in format {:name_of_the_ref => [:attribute1, :attribute2]}
        def initialize(inventory_collection, secondary_refs = {})
          @inventory_collection = inventory_collection

          @primary_ref    = {primary_index_ref => @inventory_collection.manager_ref}
          @secondary_refs = secondary_refs
          @all_refs       = @primary_ref.merge(@secondary_refs)

          @data_indexes     = {}
          @local_db_indexes = {}

          @all_refs.each do |index_name, attribute_names|
            @data_indexes[index_name] = ManagerRefresh::InventoryCollection::Index::Type::Data.new(
              inventory_collection,
              index_name,
              attribute_names
            )

            @local_db_indexes[index_name] = ManagerRefresh::InventoryCollection::Index::Type::LocalDb.new(
              inventory_collection,
              index_name,
              attribute_names,
              @data_indexes[index_name]
            )
          end

          @skeletal_primary_index = ManagerRefresh::InventoryCollection::Index::Type::Skeletal.new(
            inventory_collection,
            :skeletal_primary_index_ref,
            named_ref,
            primary_index
          )
        end

        # Builds primary index for passed InventoryObject
        #
        # @param inventory_object [ManagerRefresh::InventoryObject] InventoryObject we want to index
        # @return [ManagerRefresh::InventoryObject] Passed InventoryObject
        def build_primary_index_for(inventory_object)
          # Building the object, we need to provide all keys of a primary index
          assert_index(inventory_object.data, primary_index_ref)
          primary_index.store_index_for(inventory_object)
        end

        def build_secondary_indexes_for(inventory_object)
          secondary_refs.keys.each do |ref|
            data_index(ref).store_index_for(inventory_object)
          end
        end

        def reindex_secondary_indexes!
          data_indexes.each do |ref, index|
            next if ref == primary_index_ref

            index.reindex!
          end
        end

        def primary_index
          data_index(primary_index_ref)
        end

        def find(reference, ref: primary_index_ref)
          # TODO(lsmola) lazy_find will support only hash, then we can remove the _by variant
          # TODO(lsmola) this method should return lazy too, the rest of the finders should be deprecated
          return if reference.nil?
          return unless assert_index(reference, ref)

          reference = inventory_collection.build_reference(reference, ref)

          case strategy
          when :local_db_find_references, :local_db_cache_all
            local_db_index_find(reference)
          when :local_db_find_missing_references
            find_in_data_or_skeletal_index(reference) || local_db_index_find(reference)
          else
            find_in_data_or_skeletal_index(reference)
          end
        end

        def find_by(manager_uuid_hash, ref: primary_index_ref)
          # TODO(lsmola) deprecate this, it's enough to have find method
          find(manager_uuid_hash, :ref => ref)
        end

        def lazy_find_by(manager_uuid_hash, ref: primary_index_ref, key: nil, default: nil)
          # TODO(lsmola) deprecate this, it's enough to have lazy_find method

          lazy_find(manager_uuid_hash, :ref => ref, :key => key, :default => default)
        end

        def lazy_find(manager_uuid, ref: primary_index_ref, key: nil, default: nil)
          # TODO(lsmola) also, it should be enough to have only 1 find method, everything can be lazy, until we try to
          # access the data
          # TODO(lsmola) lazy_find will support only hash, then we can remove the _by variant
          return if manager_uuid.nil?
          return unless assert_index(manager_uuid, ref)

          ::ManagerRefresh::InventoryObjectLazy.new(inventory_collection,
                                                    manager_uuid,
                                                    :ref => ref, :key => key, :default => default)
        end

        def named_ref(ref = primary_index_ref)
          all_refs[ref]
        end

        private

        delegate :association_to_foreign_key_mapping,
                 :build_stringified_reference,
                 :parallel_safe?,
                 :strategy,
                 :to => :inventory_collection

        attr_reader :all_refs, :data_indexes, :inventory_collection, :primary_ref, :local_db_indexes, :secondary_refs

        def find_in_data_or_skeletal_index(reference)
          if parallel_safe?
            # With parallel safe strategies, we create skeletal nodes that we can look for
            data_index_find(reference) || skeletal_index_find(reference)
          else
            data_index_find(reference)
          end
        end

        def skeletal_index_find(reference)
          # Find in skeletal index, but we are able to create skeletal index only for primary indexes
          skeletal_primary_index.find(reference.stringified_reference) if reference.primary?
        end

        def data_index_find(reference)
          data_index(reference.ref).find(reference.stringified_reference)
        end

        def local_db_index_find(reference)
          local_db_index(reference.ref).find(reference)
        end

        def primary_index_ref
          :manager_ref
        end

        def data_index(name)
          data_indexes[name] || raise("Index :#{name} not defined for #{inventory_collection}")
        end

        def local_db_index(name)
          local_db_indexes[name] || raise("Index :#{name} not defined for #{inventory_collection}")
        end

        def missing_keys(data_keys, ref)
          named_ref(ref) - data_keys
        end

        def required_index_keys_present?(data_keys, ref)
          missing_keys(data_keys, ref).empty?
        end

        def assert_relation_keys(data, ref)
          named_ref(ref).each do |key|
            # Skip if the key is not a foreign key
            next unless association_to_foreign_key_mapping[key]
            # Skip if data on key are nil or InventoryObject or InventoryObjectLazy
            next if data[key].nil? || data[key].kind_of?(ManagerRefresh::InventoryObject) || data[key].kind_of?(ManagerRefresh::InventoryObjectLazy)
            # Raise error since relation must be nil or InventoryObject or InventoryObjectLazy
            raise "Wrong index for key :#{key}, the value must be of type Nil or InventoryObject or InventoryObjectLazy, got: #{data[key]}"
          end
        end

        def assert_index(manager_uuid, ref)
          # TODO(lsmola) do we need some production logging too? Maybe the refresh log level could drive this
          # Let' do this really slick development and test env, but disable for production, since the checks are pretty
          # slow.
          return if Rails.env.production?

          if manager_uuid.kind_of?(ManagerRefresh::InventoryCollection::Reference)
            # ManagerRefresh::InventoryCollection::Reference has been already asserted, skip
          elsif manager_uuid.kind_of?(Hash)
            # Test we are sending all keys required for the index
            unless required_index_keys_present?(manager_uuid.keys, ref)
              raise "Finder has missing keys for index :#{ref}, missing indexes are: #{missing_keys(manager_uuid.keys, ref)}"
            end
            # Test that keys, that are relations, are nil or InventoryObject or InventoryObjectlazy class
            assert_relation_keys(manager_uuid, ref)
          else
            # Check that other value (possibly String or Integer)) has no composite index
            if named_ref(ref).size > 1
              right_format = "collection.find(#{named_ref(ref).map { |x| ":#{x} => 'X'" }.join(", ")}"

              raise "The index :#{ref} has composite index, finder has to be called as: #{right_format})"
            end

            # Assert the that possible relation is nil or InventoryObject or InventoryObjectlazy class
            assert_relation_keys({named_ref(ref).first => manager_uuid}, ref)
          end

          true
        rescue => e
          _log.error("Error when asserting index: #{manager_uuid}, with ref: #{ref} of: #{inventory_collection}")
          raise e
        end
      end
    end
  end
end
