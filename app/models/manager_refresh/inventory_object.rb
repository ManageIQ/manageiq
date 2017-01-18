module ManagerRefresh
  class InventoryObject
    attr_accessor :object, :id
    attr_reader :inventory_collection, :data

    delegate :manager_ref, :to => :inventory_collection
    delegate :[], :[]=, :to => :data

    def initialize(inventory_collection, data)
      @inventory_collection     = inventory_collection
      @data                     = data
      @object                   = nil
      @id                       = nil
      @allowed_attributes_index = nil
    end

    def manager_uuid
      manager_ref.map { |attribute| data[attribute].try(:id) || data[attribute].to_s }.join("__")
    end

    def load
      id
    end

    def attributes(inventory_collection_scope = nil)
      # TODO(lsmola) mark method with !, for performance reasons, this methods can be called only once, the second
      # call will not return saveable result. We do not want to cache the result, since we want the lowest memory
      # footprint.

      # We should explicitly pass a scope, since the inventory_object can be mapped to more InventoryCollections with
      # different blacklist and whitelist. The generic code always passes a scope.
      inventory_collection_scope ||= inventory_collection

      attributes_for_saving = {}
      # First transform the values
      data.each do |key, value|
        if !allowed?(inventory_collection_scope, key)
          next
        elsif loadable?(value)
          # Lets fill also the original data, so other InventoryObject referring to this attribute gets the right
          # result
          data[key] = value.load
          if (foreign_key = inventory_collection_scope.association_to_foreign_key_mapping[key])
            # We have an association to fill, lets fill also the :key, cause some other InventoryObject can refer to it
            attributes_for_saving[foreign_key] = data[key]

            if (foreign_type = inventory_collection_scope.association_to_foreign_type_mapping[key])
              # If we have a polymorphic association, we need to also fill a base class name
              attributes_for_saving[foreign_type] = value.inventory_collection.base_class_name
            end
          else
            # We have a normal attribute to fill, or not an Activerecord association, like Ancestry, or any custom
            # attribute used in e.g. after_save hook, we can't process them automatically
            attributes_for_saving[key] = data[key]
          end
        elsif value.kind_of?(Array) && value.any? { |x| loadable?(x) }
          # Lets fill also the original data, so other InventoryObject referring to this attribute gets the right
          # result
          data[key]                                            = value.compact.map(&:load).compact
          # We can use built in _ids methods to assign array of ids into has_many relations. So e.g. the :key_pairs=
          # relation setter will become :key_pair_ids=
          attributes_for_saving[key.to_s.singularize + "_ids"] = data[key]
        else
          attributes_for_saving[key] = value
        end
      end

      attributes_for_saving
    end

    def to_s
      "InventoryObject:('#{manager_uuid}', #{inventory_collection})"
    end

    def inspect
      to_s
    end

    private

    def association?(inventory_collection_scope, key)
      # Is the key an association on inventory_collection_scope model class?
      !inventory_collection_scope.association_to_foreign_key_mapping[key].nil?
    end

    def allowed?(inventory_collection_scope, key)
      foreign_to_association  = inventory_collection_scope.foreign_key_to_association_mapping[key] ||
        inventory_collection_scope.foreign_type_to_association_mapping[key]

      # TODO(lsmola) can we make this O(1)? This check will be performed for each record in the DB
      return false if inventory_collection_scope.attributes_blacklist.present? &&
        (inventory_collection_scope.attributes_blacklist.include?(key) ||
          (foreign_to_association && inventory_collection_scope.attributes_blacklist.include?(foreign_to_association)))

      return false if inventory_collection_scope.attributes_whitelist.present? &&
        (!inventory_collection_scope.attributes_whitelist.include?(key) &&
          (!foreign_to_association || (foreign_to_association && inventory_collection_scope.attributes_whitelist.include?(foreign_to_association))))

      true
    end

    def loadable?(value)
      value.kind_of?(::ManagerRefresh::InventoryObjectLazy) || value.kind_of?(::ManagerRefresh::InventoryObject)
    end
  end
end
