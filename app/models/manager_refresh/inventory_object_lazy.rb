module ManagerRefresh
  class InventoryObjectLazy
    include Vmdb::Logging

    attr_reader :ems_ref, :inventory_collection, :key, :default

    def initialize(inventory_collection, ems_ref, key: nil, default: nil)
      @ems_ref              = ems_ref
      @inventory_collection = inventory_collection
      @key                  = key
      @default              = default
    end

    def to_s
      ems_ref
    end

    def inspect
      suffix = ""
      suffix += ", key: #{key}" if key.present?
      "InventoryObjectLazy:('#{self}', #{inventory_collection})#{suffix}"
    end

    def load
      key ? load_object_with_key : load_object
    end

    def dependency?
      # If key is not set, InventoryObjectLazy is a dependency, cause it points to the record itself. Otherwise
      # InventoryObjectLazy is a dependency only if it points to an attribute which is a dependency or a relation.
      !!(!key || transitive_dependency?)
    end

    def transitive_dependency?
      # If the dependency is inventory_collection.lazy_find(:ems_ref, :key => :stack)
      # and a :stack is a relation to another object, in the InventoryObject object,
      # then this relation is considered transitive.
      !!(key && (inventory_collection.dependency_attributes.keys.include?(key) ||
        inventory_collection.model_class.reflect_on_association(key)))
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
      inventory_collection_member = inventory_collection.find(to_s)
      inventory_collection_member.respond_to?(:object) ? inventory_collection_member.object : inventory_collection_member
    end
  end
end
