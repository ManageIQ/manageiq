module ManagerRefresh
  class InventoryCollection
    attr_accessor :saved

    attr_reader :model_class, :strategy, :attributes_blacklist, :attributes_whitelist, :custom_save_block, :parent,
                :internal_attributes, :delete_method, :data, :data_index, :dependency_attributes, :manager_ref,
                :association, :complete, :update_only, :transitive_dependency_attributes, :custom_manager_uuid,
                :custom_db_finder, :check_changed, :arel

    delegate :each, :size, :to => :to_a

    def initialize(model_class, manager_ref: nil, association: nil, parent: nil, strategy: nil, saved: nil,
                   custom_save_block: nil, delete_method: nil, data_index: nil, data: nil, dependency_attributes: nil,
                   attributes_blacklist: nil, attributes_whitelist: nil, complete: nil, update_only: nil,
                   check_changed: nil, custom_manager_uuid: nil, custom_db_finder: nil, arel: nil)
      @model_class                      = model_class
      @manager_ref                      = manager_ref || [:ems_ref]
      @custom_manager_uuid              = custom_manager_uuid
      @custom_db_finder                 = custom_db_finder
      @association                      = association || []
      @parent                           = parent || nil
      @arel                             = arel
      @dependency_attributes            = dependency_attributes || {}
      @transitive_dependency_attributes = Set.new
      @data                             = data || []
      @data_index                       = data_index || {}
      @saved                            = saved || false
      @strategy                         = process_strategy(strategy)
      @delete_method                    = delete_method || :destroy
      @attributes_blacklist             = Set.new
      @attributes_whitelist             = Set.new
      @custom_save_block                = custom_save_block
      @check_changed                    = check_changed.nil? ? true : check_changed
      @internal_attributes              = [:__feedback_edge_set_parent]
      @complete                         = complete.nil? ? true : complete
      @update_only                      = update_only.nil? ? false : update_only

      blacklist_attributes!(attributes_blacklist) if attributes_blacklist.present?
      whitelist_attributes!(attributes_whitelist) if attributes_whitelist.present?

      validate_inventory_collection!
    end

    def to_a
      data
    end

    def to_hash
      data_index
    end

    def process_strategy(strategy_name)
      case strategy_name
      when :local_db_cache_all, :local_db_find_one
        send("process_strategy_#{strategy_name}")
      when :find_missing_in_local_db
      end
      strategy_name
    end

    def load_from_db
      return arel unless arel.nil?
      parent.send(association)
    end

    def process_strategy_local_db_cache_all
      self.saved = true
      # TODO(lsmola) selected need to contain also :keys used in other InventoryCollections pointing to this one, once
      # we get list of all keys for each InventoryCollection ,we can uncomnent
      # selected   = [:id] + manager_ref.map { |x| model_class.reflect_on_association(x).try(:foreign_key) || x }
      # selected << :type if model_class.new.respond_to? :type
      # load_from_db.select(selected).find_each do |record|
      load_from_db.find_each do |record|
        if custom_manager_uuid.nil?
          index = object_index(record)
        else
          index = stringify_reference(custom_manager_uuid.call(record))
        end
        self.data_index[index] = new_inventory_object(record.attributes.symbolize_keys)
        # TODO(lsmola) get rid of storing objects, they are causing memory bloat
        self.data_index[index].object = record
      end
    end

    def process_strategy_local_db_find_one
      self.saved = true
    end

    def check_changed?
      check_changed
    end

    def complete?
      complete
    end

    def update_only?
      update_only
    end

    def delete_allowed?
      complete? && !update_only?
    end

    def create_allowed?
      !update_only?
    end

    def saved?
      saved
    end

    def saveable?
      dependencies.all?(&:saved?)
    end

    def <<(inventory_object)
      unless data_index[inventory_object.manager_uuid]
        data_index[inventory_object.manager_uuid] = inventory_object
        data << inventory_object

        actualize_dependencies(inventory_object)
      end
    end

    def object_index(object)
      stringify_reference(
        manager_ref.map { |attribute| object.public_send(attribute).try(:id) || object.public_send(attribute).to_s })
    end

    def stringify_joiner
      "__"
    end

    def stringify_reference(reference)
      reference.join(stringify_joiner)
    end

    def manager_ref_to_cols
      # Convert attributes from uniqe key to actual db cols
      required_relations = dependency_attributes_for(fixed_dependencies).to_a
      manager_ref.map do |ref|
        if required_relations.include?(ref)
          model_class.reflect_on_association(ref).foreign_key
        else
          ref
        end
      end
    end

    def object_index_with_keys(keys, object)
      keys.map { |attribute| object.public_send(attribute).to_s }.join(stringify_joiner)
    end

    def find(manager_uuid)
      return if manager_uuid.nil?
      case strategy
      when :local_db_find_one
        find_in_db(manager_uuid)
      when :find_missing_in_local_db
        data_index[manager_uuid] || find_in_db(manager_uuid)
      else
        data_index[manager_uuid]
      end
    end

    def find_in_db(manager_uuid)
      manager_uuids    = manager_uuid.split(stringify_joiner)
      hash_uuid_by_ref = manager_ref.zip(manager_uuids).to_h
      record           = if custom_db_finder.nil?
                           parent.send(association).where(hash_uuid_by_ref).first
                         else
                           custom_db_finder.call(self, hash_uuid_by_ref)
                         end
      return unless record

      inventory_object = new_inventory_object(record.attributes.symbolize_keys)
      # TODO(lsmola) get rid of storing objects, they are causing memory bloat
      inventory_object.object = record
      inventory_object
    end

    def lazy_find(manager_uuid, key: nil, default: nil)
      ::ManagerRefresh::InventoryObjectLazy.new(self, manager_uuid, :key => key, :default => default)
    end

    def new_inventory_object(hash)
      ::ManagerRefresh::InventoryObject.new(self, hash)
    end

    def filtered_dependency_attributes
      filtered_attributes = dependency_attributes

      if attributes_blacklist.present?
        filtered_attributes = filtered_attributes.reject { |key, _value| attributes_blacklist.include?(key) }
      end

      if attributes_whitelist.present?
        filtered_attributes = filtered_attributes.reject { |key, _value| !attributes_whitelist.include?(key) }
      end

      filtered_attributes
    end

    def fixed_attributes
      presence_validators = model_class.validators.detect { |x| x.kind_of? ActiveRecord::Validations::PresenceValidator }
      # Attributes that has to be always on the entity, so attributes making unique index of the record + attributes
      # that have presence validation
      fixed_attributes    = manager_ref
      fixed_attributes    += presence_validators.attributes unless presence_validators.blank?
      fixed_attributes
    end

    def fixed_dependencies
      fixed_attrs        = fixed_attributes
      fixed_dependencies = Set.new
      filtered_dependency_attributes.each do |key, value|
        fixed_dependencies += value if fixed_attrs.include?(key)
      end
      fixed_dependencies
    end

    def dependencies
      filtered_dependency_attributes.values.map(&:to_a).flatten.uniq
    end

    def dependency_attributes_for(inventory_collections)
      attributes = Set.new
      inventory_collections.each do |inventory_collection|
        attributes += filtered_dependency_attributes.select { |_key, value| value.include?(inventory_collection) }.keys
      end
      attributes
    end

    def blacklist_attributes!(attributes)
      # The manager_ref attributes cannot be blacklisted, otherwise we will not be able to identify the
      # inventory_object. We do not automatically remove attributes causing fixed dependencies, so beware that without
      # them, you won't be able to create the record.
      self.attributes_blacklist += attributes - (fixed_attributes + internal_attributes)
    end

    def whitelist_attributes!(attributes)
      # The manager_ref attributes always needs to be in the white list, otherwise we will not be able to identify the
      # inventory_object. We do not automatically add attributes causing fixed dependencies, so beware that without
      # them, you won't be able to create the record.
      self.attributes_whitelist += attributes + (fixed_attributes + internal_attributes)
    end

    def clone
      # A shallow copy of InventoryCollection, the copy will share @data of the original collection, otherwise we would
      # be copying a lot of records in memory.
      self.class.new(model_class,
                     :manager_ref           => manager_ref,
                     :association           => association,
                     :parent                => parent,
                     :arel                  => arel,
                     :strategy              => strategy,
                     :custom_save_block     => custom_save_block,
                     :data                  => data,
                     :data_index            => data_index,
                     # Dependency attributes need to be a hard copy, since those will differ for each
                     # InventoryCollection
                     :dependency_attributes => dependency_attributes.clone)
    end

    def to_s
      whitelist = ", whitelist: [#{attributes_whitelist.to_a.join(", ")}]" unless attributes_whitelist.blank?
      blacklist = ", blacklist: [#{attributes_blacklist.to_a.join(", ")}]" unless attributes_blacklist.blank?

      strategy_name  = ", strategy: #{strategy}" if strategy

      "InventoryCollection:<#{@model_class}>#{whitelist}#{blacklist}#{strategy_name}"
    end

    def inspect
      to_s
    end

    private

    attr_writer :attributes_blacklist, :attributes_whitelist

    def actualize_dependencies(inventory_object)
      inventory_object.data.each do |key, value|
        if dependency?(value)
          (dependency_attributes[key] ||= Set.new) << value.inventory_collection
          self.transitive_dependency_attributes << key if transitive_dependency?(value)
        elsif value.kind_of?(Array) && value.any? { |x| dependency?(x) }
          (dependency_attributes[key] ||= Set.new) << value.detect { |x| dependency?(x) }.inventory_collection
          self.transitive_dependency_attributes << key if value.any? { |x| transitive_dependency?(x) }
        end
      end
    end

    def dependency?(value)
      (value.kind_of?(::ManagerRefresh::InventoryObjectLazy) && value.dependency?) ||
        value.kind_of?(::ManagerRefresh::InventoryObject)
    end

    def transitive_dependency?(value)
      # If the dependency is inventory_collection.lazy_find(:ems_ref, :key => :stack)
      # and a :stack is a relation to another object, in the InventoryObject object,
      # then this dependency is considered transitive.
      (value.kind_of?(::ManagerRefresh::InventoryObjectLazy) && value.transitive_dependency?)
    end

    def validate_inventory_collection!
      if @strategy == :local_db_cache_all
        if (manager_ref & association_attributes).present?
          # Our manager_ref unique key contains a reference, that means that index we get from the API and from the
          # db will differ. We need a custom indexing method, so the indexing is correct.
          raise "The unique key list manager_ref contains a reference, which can't be built automatically when loading"\
                " the InventoryCollection from the DB, you need to provide a custom_manager_uuid lambda, that builds"\
                " the correct manager_uuid given a DB record" if custom_manager_uuid.nil?
        end
      end
    end

    def association_attributes
      # All association attributes and foreign keys of the model class
      model_class.reflect_on_all_associations.map { |x| [x.name, x.foreign_key] }.flatten.compact.map(&:to_sym)
    end
  end
end
