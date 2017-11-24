module ManagerRefresh
  class InventoryCollection
    module Index
      class Proxy
        include Vmdb::Logging

        def initialize(inventory_collection, secondary_refs)
          @inventory_collection = inventory_collection

          main_ref       = {:manager_ref => inventory_collection.manager_ref}
          secondary_refs = secondary_refs
          @all_refs      = main_ref.merge(secondary_refs)

          @data_indexes     = {}
          @local_db_indexes = {}

          @all_refs.each do |index_name, attribute_names|
            @data_indexes[index_name] = ManagerRefresh::InventoryCollection::Index::Type::Data.new(
              inventory_collection,
              attribute_names
            )

            @local_db_indexes[index_name] = ManagerRefresh::InventoryCollection::Index::Type::LocalDb.new(
              inventory_collection,
              attribute_names,
              @data_indexes[index_name]
            )
          end
        end

        def store_indexes_for_inventory_object(inventory_object)
          data_indexes.values.each do |index|
            index.store_index_for(inventory_object)
          end
        end

        def primary_index
          data_index(:manager_ref)
        end

        def find(manager_uuid, ref: :manager_ref)
          # TODO(lsmola) lazy_find will support only hash, then we can remove the _by variant
          return if manager_uuid.nil?

          manager_uuid = stringify_index_value(manager_uuid, ref)

          return unless assert_index(manager_uuid, ref)

          case strategy
          when :local_db_find_references, :local_db_cache_all
            local_db_index(ref).find(manager_uuid)
          when :local_db_find_missing_references
            data_index(ref).find(manager_uuid) || local_db_index(ref).find(manager_uuid)
          else
            data_index(ref).find(manager_uuid)
          end
        end

        def find_by(manager_uuid_hash, ref: :manager_ref)
          # TODO(lsmola) deprecate this, it's enough to have find method
          find(manager_uuid_hash, :ref => ref)
        end

        def lazy_find_by(manager_uuid_hash, ref: :manager_ref, key: nil, default: nil)
          # TODO(lsmola) deprecate this, it's enough to have lazy_find method

          lazy_find(manager_uuid_hash, :ref => ref, :key => key, :default => default)
        end

        def lazy_find(manager_uuid, ref: :manager_ref, key: nil, default: nil)
          # TODO(lsmola) also, it should be enough to have only 1 find method, everything can be lazy, until we try to
          # access the data
          # TODO(lsmola) lazy_find will support only hash, then we can remove the _by variant
          return if manager_uuid.nil?
          return unless assert_index(manager_uuid, ref)

          ::ManagerRefresh::InventoryObjectLazy.new(inventory_collection,
                                                    stringify_index_value(manager_uuid, ref),
                                                    manager_uuid,
                                                    :ref => ref, :key => key, :default => default)
        end

        private

        delegate :strategy, :hash_index_with_keys, :to => :inventory_collection

        attr_reader :all_refs, :data_indexes, :local_db_indexes, :inventory_collection

        def stringify_index_value(index_value, ref)
          # TODO(lsmola) !!!!!!!!!! Important, move this inside of the index. We should be passing around a full hash
          # index. Then all references should be turned into {stringified_index => full_index} hash. So that way, we can
          # keep fast indexing using string, but we can use references to write queries autmatically (targeted,
          # db_based, etc.)
          # We can also save {stringified_index => full_index}, so we don't have to compute it twice.
          if index_value.kind_of?(Hash)
            hash_index_with_keys(named_ref(ref), index_value)
          else
            # TODO(lsmola) raise deprecation warning, we want to use only hash indexes
            index_value
          end
        end

        def data_index(name)
          data_indexes[name] || raise("Index #{name} not defined for #{inventory_collection}")
        end

        def local_db_index(name)
          local_db_indexes[name] || raise("Index #{name} not defined for #{inventory_collection}")
        end

        def named_ref(ref)
          all_refs[ref]
        end

        def assert_index(manager_uuid, ref)
          if manager_uuid.kind_of?(Hash)
            # Test we are sending all keys required for the index
            unless (named_ref(ref) - manager_uuid.keys).empty?
              if !Rails.env.production?
                raise "Invalid finder on '#{inventory_collection}' using #{manager_uuid}. Needed find_by keys for #{ref} are #{named_ref(ref)}"
              else
                _log.error("Invalid finder on '#{inventory_collection}' using #{manager_uuid}. Needed find_by keys for #{ref} are #{named_ref(ref)}")
                return false
              end
            end
          else
            # TODO(lsmola) we convert the Hash to String in lazy_find_ so we can't test it like this
            # if named_ref(ref).count > 1
            #   if !Rails.env.production?
            #     raise "Invalid finder on #{inventory_collection} using #{manager_uuid}. We expect Hash with keys #{named_ref(ref)}"
            #   else
            #     _log.error("Invalid finder on #{inventory_collection} using #{manager_uuid}. We expect Hash with keys #{named_ref(ref)}")
            #   end
            # end
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
