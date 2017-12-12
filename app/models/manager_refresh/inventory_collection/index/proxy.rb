module ManagerRefresh
  class InventoryCollection
    module Index
      class Proxy
        include Vmdb::Logging

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
        end

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
          # TODO(lsmola) this method shoul return lazy too, the rest of the finders should be deprecated
          return if reference.nil?
          return unless assert_index(reference, ref)

          reference = inventory_collection.build_reference(reference, ref)

          case strategy
          when :local_db_find_references, :local_db_cache_all
            local_db_index_find(reference)
          when :local_db_find_missing_references
            data_index_find(reference) || local_db_index_find(reference)
          else
            data_index_find(reference)
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

        def named_ref(ref)
          all_refs[ref]
        end

        private

        delegate :build_stringified_reference, :strategy, :to => :inventory_collection

        attr_reader :all_refs, :data_indexes, :inventory_collection, :primary_ref, :local_db_indexes, :secondary_refs

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
          data_indexes[name] || raise("Index #{name} not defined for #{inventory_collection}")
        end

        def local_db_index(name)
          local_db_indexes[name] || raise("Index #{name} not defined for #{inventory_collection}")
        end

        def missing_keys(data_keys, ref)
          named_ref(ref) - data_keys
        end

        def required_index_keys_present?(data_keys, ref)
          missing_keys(data_keys, ref).empty?
        end

        def assert_index(manager_uuid, ref)
          if manager_uuid.kind_of?(Hash)
            # Test we are sending all keys required for the index
            unless required_index_keys_present?(manager_uuid.keys, ref)
              missing_keys = missing_keys(manager_uuid.keys, ref)

              if !Rails.env.production?
                raise "Invalid index for '#{inventory_collection}' using #{manager_uuid}. Missing keys for index #{ref} are #{missing_keys}"
              else
                _log.error("Invalid index for '#{inventory_collection}' using #{manager_uuid}. Missing keys for index #{ref} are #{missing_keys}")
                return false
              end
            end
          end

          true
        rescue => e
          _log.error("Error when asserting index: #{manager_uuid}, with ref: #{ref} of #{inventory_collection}")
          raise e
        end
      end
    end
  end
end
