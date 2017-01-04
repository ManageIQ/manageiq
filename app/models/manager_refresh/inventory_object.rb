module ManagerRefresh
  class InventoryObject
    attr_accessor :object
    attr_reader :inventory_collection, :data

    delegate :manager_ref, :to => :inventory_collection
    delegate :id, :to => :object, :allow_nil => true
    delegate :[], :[]=, :to => :data

    def initialize(inventory_collection, data)
      @inventory_collection     = inventory_collection
      @data                     = data
      @object                   = nil
      @allowed_attributes_index = nil
    end

    def manager_uuid
      manager_ref.map { |attribute| data[attribute].try(:id) || data[attribute].to_s }.join("__")
    end

    def load
      object
    end

    def attributes(inventory_collection_scope = nil)
      # We should explicitly pass a scope, since the inventory_object can be mapped to more InventoryCollections with different blacklist
      # and whitelist. The generic code always passes a scope.
      inventory_collection_scope ||= inventory_collection

      # First transform the values
      data.each do |key, value|
        if !allowed?(inventory_collection_scope, key)
          next
        elsif loadable?(value)
          data[key] = value.load
        elsif value.kind_of?(Array) && value.any? { |x| loadable?(x) }
          data[key] = value.compact.map(&:load).compact
        else
          next
        end
      end

      # Then return a new hash containing only the values according to the whitelist and the blacklist
      data.select { |key, _value| allowed?(inventory_collection_scope, key) }
    end

    def to_s
      "InventoryObject:('#{manager_uuid}', #{inventory_collection})"
    end

    def inspect
      to_s
    end

    private

    def allowed?(inventory_collection_scope, key)
      # TODO(lsmola) can we make this O(1)? This check will be performed for each record in the DB

      return false if inventory_collection_scope.attributes_blacklist.present? && inventory_collection_scope.attributes_blacklist.include?(key)
      return false if inventory_collection_scope.attributes_whitelist.present? && !inventory_collection_scope.attributes_whitelist.include?(key)
      true
    end

    def loadable?(value)
      value.kind_of?(::ManagerRefresh::InventoryObjectLazy) || value.kind_of?(::ManagerRefresh::InventoryObject)
    end
  end
end
