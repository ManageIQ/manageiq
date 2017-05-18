module ManagerRefresh
  class InventoryObject
    attr_accessor :object, :id
    attr_reader :inventory_collection, :data

    delegate :manager_ref, :base_class_name, :model_class, :to => :inventory_collection
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

    def to_raw_lazy_relation
      {
        :type                      => "ManagerRefresh::InventoryObjectLazy",
        :inventory_collection_name => inventory_collection.name,
        :ems_ref                   => manager_uuid,
      }
    end

    def load
      self
    end

    def attributes(inventory_collection_scope = nil)
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
            record_id                          = data[key].try(:id)
            attributes_for_saving[foreign_key] = record_id

            if (foreign_type = inventory_collection_scope.association_to_foreign_type_mapping[key])
              # If we have a polymorphic association, we need to also fill a base class name, but we want to nullify it
              # if record_id is missing
              attributes_for_saving[foreign_type] = record_id ? data[key].base_class_name : nil
            end
          elsif data[key].kind_of?(::ManagerRefresh::InventoryObject)
            # We have an association to fill but not an Activerecord association, so e.g. Ancestry, lets just load
            # it here. This way of storing ancestry is ineffective in DB call count, but RAM friendly
            attributes_for_saving[key] = data[key].base_class_name.constantize.find_by(:id => data[key].id)
          else
            # We have a normal attribute to fill
            attributes_for_saving[key] = data[key]
          end
        elsif value.kind_of?(Array) && value.any? { |x| loadable?(x) }
          # Lets fill also the original data, so other InventoryObject referring to this attribute gets the right
          # result
          data[key]                                            = value.compact.map(&:load).compact
          # We can use built in _ids methods to assign array of ids into has_many relations. So e.g. the :key_pairs=
          # relation setter will become :key_pair_ids=
          attributes_for_saving[key.to_s.singularize + "_ids"] = data[key].map(&:id).compact
        else
          attributes_for_saving[key] = value
        end
      end

      attributes_for_saving
    end

    def assign_attributes(attributes)
      attributes.each { |k, v| public_send("#{k}=", v) }
      self
    end

    def to_s
      manager_uuid
    end

    def inspect
      "InventoryObject:('#{manager_uuid}', #{inventory_collection})"
    end

    def dependency?
      true
    end

    def self.add_attributes(inventory_object_attributes)
      inventory_object_attributes.each do |attr|
        define_method("#{attr}=") do |value|
          data[attr] = value
        end

        define_method(attr) do
          data[attr]
        end
      end
    end

    private

    def association?(inventory_collection_scope, key)
      # Is the key an association on inventory_collection_scope model class?
      !inventory_collection_scope.association_to_foreign_key_mapping[key].nil?
    end

    def allowed?(inventory_collection_scope, key)
      foreign_to_association = inventory_collection_scope.foreign_key_to_association_mapping[key] ||
                               inventory_collection_scope.foreign_type_to_association_mapping[key]

      return false if inventory_collection_scope.attributes_blacklist.present? &&
                      (inventory_collection_scope.attributes_blacklist.include?(key) ||
                        (foreign_to_association && inventory_collection_scope.attributes_blacklist.include?(foreign_to_association)))

      return false if inventory_collection_scope.attributes_whitelist.present? &&
                      (!inventory_collection_scope.attributes_whitelist.include?(key) &&
                        (!foreign_to_association || (foreign_to_association && inventory_collection_scope.attributes_whitelist.include?(foreign_to_association))))

      true
    end

    def loadable?(value)
      value.kind_of?(::ManagerRefresh::InventoryObjectLazy) || value.kind_of?(::ManagerRefresh::InventoryObject) ||
        value.kind_of?(::ManagerRefresh::ApplicationRecordReference)
    end
  end
end
