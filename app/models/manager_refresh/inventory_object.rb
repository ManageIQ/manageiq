module ManagerRefresh
  class InventoryObject
    attr_accessor :object, :id
    attr_reader :inventory_collection, :data, :reference

    delegate :manager_ref, :base_class_name, :model_class, :to => :inventory_collection
    delegate :[], :[]=, :to => :data

    # @param inventory_collection [ManagerRefresh::InventoryCollection] InventoryCollection object owning the
    #        InventoryObject
    # @param data [Hash] Data of the InventoryObject object
    def initialize(inventory_collection, data)
      @inventory_collection     = inventory_collection
      @data                     = data
      @object                   = nil
      @id                       = nil
      @reference                = inventory_collection.build_reference(data)
    end

    # @return [String] stringified reference
    def manager_uuid
      reference.stringified_reference
    end

    # @return [ManagerRefresh::InventoryObject] returns self
    def load
      self
    end

    # Transforms InventoryObject object data into hash format with keys that are column names and resolves correct
    # values of the foreign keys (even the polymorphic ones)
    #
    # @param inventory_collection_scope [ManagerRefresh::InventoryCollection] parent InventoryCollection object
    # @return [Hash] Data in DB format
    def attributes(inventory_collection_scope = nil)
      # We should explicitly pass a scope, since the inventory_object can be mapped to more InventoryCollections with
      # different blacklist and whitelist. The generic code always passes a scope.
      inventory_collection_scope ||= inventory_collection

      attributes_for_saving = {}
      # First transform the values
      data.each do |key, value|
        if !allowed?(inventory_collection_scope, key)
          next
        elsif value.kind_of?(Array) && value.any? { |x| loadable?(x) }
          # Lets fill also the original data, so other InventoryObject referring to this attribute gets the right
          # result
          data[key] = value.compact.map(&:load).compact
          # We can use built in _ids methods to assign array of ids into has_many relations. So e.g. the :key_pairs=
          # relation setter will become :key_pair_ids=
          attributes_for_saving[(key.to_s.singularize + "_ids").to_sym] = data[key].map(&:id).compact.uniq
        elsif loadable?(value) || inventory_collection_scope.association_to_foreign_key_mapping[key]
          # Lets fill also the original data, so other InventoryObject referring to this attribute gets the right
          # result
          data[key] = value.load if value.respond_to?(:load)
          if (foreign_key = inventory_collection_scope.association_to_foreign_key_mapping[key])
            # We have an association to fill, lets fill also the :key, cause some other InventoryObject can refer to it
            record_id                                 = data[key].try(:id)
            attributes_for_saving[foreign_key.to_sym] = record_id

            if (foreign_type = inventory_collection_scope.association_to_foreign_type_mapping[key])
              # If we have a polymorphic association, we need to also fill a base class name, but we want to nullify it
              # if record_id is missing
              base_class = data[key].try(:base_class_name) || data[key].class.try(:base_class).try(:name)
              attributes_for_saving[foreign_type.to_sym] = record_id ? base_class : nil
            end
          elsif data[key].kind_of?(::ManagerRefresh::InventoryObject)
            # We have an association to fill but not an Activerecord association, so e.g. Ancestry, lets just load
            # it here. This way of storing ancestry is ineffective in DB call count, but RAM friendly
            attributes_for_saving[key.to_sym] = data[key].base_class_name.constantize.find_by(:id => data[key].id)
          else
            # We have a normal attribute to fill
            attributes_for_saving[key.to_sym] = data[key]
          end
        else
          attributes_for_saving[key.to_sym] = value
        end
      end

      attributes_for_saving
    end

    # Transforms InventoryObject object data into hash format with keys that are column names and resolves correct
    # values of the foreign keys (even the polymorphic ones)
    #
    # @param inventory_collection_scope [ManagerRefresh::InventoryCollection] parent InventoryCollection object
    # @param all_attribute_keys [Array<Symbol>] Attribute keys we will modify based on object's data
    # @return [Hash] Data in DB format
    def attributes_with_keys(inventory_collection_scope = nil, all_attribute_keys = [])
      # We should explicitly pass a scope, since the inventory_object can be mapped to more InventoryCollections with
      # different blacklist and whitelist. The generic code always passes a scope.
      inventory_collection_scope ||= inventory_collection

      attributes_for_saving = {}
      # First transform the values
      data.each do |key, value|
        if !allowed?(inventory_collection_scope, key)
          next
        elsif loadable?(value) || inventory_collection_scope.association_to_foreign_key_mapping[key]
          # Lets fill also the original data, so other InventoryObject referring to this attribute gets the right
          # result
          data[key] = value.load if value.respond_to?(:load)
          if (foreign_key = inventory_collection_scope.association_to_foreign_key_mapping[key])
            # We have an association to fill, lets fill also the :key, cause some other InventoryObject can refer to it
            record_id = data[key].try(:id)
            foreign_key_to_sym = foreign_key.to_sym
            attributes_for_saving[foreign_key_to_sym] = record_id
            all_attribute_keys << foreign_key_to_sym
            if (foreign_type = inventory_collection_scope.association_to_foreign_type_mapping[key])
              # If we have a polymorphic association, we need to also fill a base class name, but we want to nullify it
              # if record_id is missing
              base_class = data[key].try(:base_class_name) || data[key].class.try(:base_class).try(:name)
              foreign_type_to_sym = foreign_type.to_sym
              attributes_for_saving[foreign_type_to_sym] = record_id ? base_class : nil
              all_attribute_keys << foreign_type_to_sym
            end
          else
            # We have a normal attribute to fill
            attributes_for_saving[key] = data[key]
            all_attribute_keys << key
          end
        else
          attributes_for_saving[key] = value
          all_attribute_keys << key
        end
      end

      attributes_for_saving
    end

    # Given hash of attributes, we assign them to InventoryObject object using its public writers
    #
    # @param attributes [Hash] attributes we want to assign
    # @return [ManagerRefresh::InventoryObject] self
    def assign_attributes(attributes)
      attributes.each { |k, v| public_send("#{k}=", v) }
      self
    end

    # @return [String] stringified UUID
    def to_s
      manager_uuid
    end

    # @return [String] string format for nice logging
    def inspect
      "InventoryObject:('#{manager_uuid}', #{inventory_collection})"
    end

    # @return [TrueClass] InventoryObject object is always a dependency
    def dependency?
      true
    end

    # Adds setters and getters based on :inventory_object_attributes kwarg passed into InventoryCollection
    #
    # @param inventory_object_attributes [Array<Symbol>]
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

    # @return [Set] all model's writer names
    def allowed_writers
      return [] unless model_class

      # Get all writers of a model
      @allowed_writers ||= (model_class.new.methods - Object.methods).grep(/^[\w]+?\=$/).to_set
    end

    # @return [Set] all model's reader names
    def allowed_readers
      return [] unless model_class

      # Get all readers inferred from writers of a model
      @allowed_readers ||= allowed_writers.map { |x| x.to_s.delete("=").to_sym }.to_set
    end

    def method_missing(method_name, *arguments, &block)
      if allowed_writers.include?(method_name)
        self.class.define_data_writer(method_name)
        public_send(method_name, arguments[0])
      elsif allowed_readers.include?(method_name)
        self.class.define_data_reader(method_name)
        public_send(method_name)
      else
        super
      end
    end

    def respond_to_missing?(method_name, _include_private = false)
      allowed_writers.include?(method_name) || allowed_readers.include?(method_name) || super
    end

    def self.define_data_writer(data_key)
      define_method(data_key) do |value|
        public_send(:[]=, data_key.to_s.delete("=").to_sym, value)
      end
    end
    private_class_method :define_data_writer

    def self.define_data_reader(data_key)
      define_method(data_key) do
        public_send(:[], data_key)
      end
    end
    private_class_method :define_data_reader

    # Return true passed key representing a getter is an association
    #
    # @param inventory_collection_scope [ManagerRefresh::InventoryCollection]
    # @param key [Symbol] key representing getter
    # @return [Boolean] true if the passed key points to association
    def association?(inventory_collection_scope, key)
      # Is the key an association on inventory_collection_scope model class?
      !inventory_collection_scope.association_to_foreign_key_mapping[key].nil?
    end

    # Return true if the attribute is allowed to be saved into the DB
    #
    # @param inventory_collection_scope [ManagerRefresh::InventoryCollection] InventoryCollection object owning the
    #        attribute
    # @param key [Symbol] attribute name
    # @return true if the attribute is allowed to be saved into the DB
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

    # Return true if the object is loadable, which we determine by a list of loadable classes.
    #
    # @param value [Object] object we test
    # @return true if the object is loadable
    def loadable?(value)
      value.kind_of?(::ManagerRefresh::InventoryObjectLazy) || value.kind_of?(::ManagerRefresh::InventoryObject) ||
        value.kind_of?(::ManagerRefresh::ApplicationRecordReference)
    end
  end
end
