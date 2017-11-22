module ManagerRefresh
  class InventoryObjectLazy
    include Vmdb::Logging

    attr_reader :ems_ref, :ref, :inventory_collection, :key, :default

    # TODO: ems_ref is inaccurate name, doubly so if it depends on ref.
    def initialize(inventory_collection, ems_ref, full_index, ref: :manager_ref, key: nil, default: nil)
      @ems_ref              = ems_ref
      @ref                  = ref
      @full_index           = full_index
      @inventory_collection = inventory_collection
      @key                  = key
      @default              = default
    end

    def to_s
      ems_ref
    end

    def inspect
      suffix = ""
      suffix += ", ref: #{ref}" if ref.present?
      suffix += ", key: #{key}" if key.present?
      "InventoryObjectLazy:('#{self}', #{inventory_collection}#{suffix})"
    end

    def to_raw_lazy_relation
      {
        :type                      => "ManagerRefresh::InventoryObjectLazy",
        :inventory_collection_name => inventory_collection.name,
        :ems_ref                   => ems_ref,
        :key                       => key,
        :default                   => default,
      }
    end

    def load
      key ? load_object_with_key : load_object
    end

    def dependency?
      # If key is not set, InventoryObjectLazy is a dependency, cause it points to the record itself. Otherwise
      # InventoryObjectLazy is a dependency only if it points to an attribute which is a dependency or a relation.
      !key || transitive_dependency?
    end

    def transitive_dependency?
      # If the dependency is inventory_collection.lazy_find(:ems_ref, :key => :stack)
      # and a :stack is a relation to another object, in the InventoryObject object,
      # then this relation is considered transitive.
      key && association?(key)
    end

    # Return if the key is an association on inventory_collection_scope model class
    def association?(key)
      # TODO(lsmola) remove this if there will be better dependency scan, probably with transitive dependencies filled
      # in a second pass, then we can get rid of this hardcoded symbols. Right now we are not able to introspect these.
      return true if [:parent, :genelogy_parent].include?(key)

      inventory_collection.dependency_attributes.key?(key) ||
        !inventory_collection.association_to_foreign_key_mapping[key].nil?
    end

    private

    def load_object_with_key
      # TODO(lsmola) Log error if we are accessing path that is present in blacklist or not present in whitelist
      found = inventory_collection.find(to_s)
      if found.present?
        if found.try(:data).present?
          found.data[key] || default
        else
          found.public_send(key)
        end
      else
        default
      end
    end

    def load_object
      inventory_collection.find(to_s, :ref => ref)
    end
  end
end
