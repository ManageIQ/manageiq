module ManagerRefresh
  class InventoryCollection
    attr_accessor :saved, :references, :data_collection_finalized

    attr_reader :model_class, :strategy, :attributes_blacklist, :attributes_whitelist, :custom_save_block, :parent,
                :internal_attributes, :delete_method, :data, :data_index, :dependency_attributes, :manager_ref,
                :association, :complete, :update_only, :transitive_dependency_attributes, :custom_manager_uuid,
                :custom_db_finder, :check_changed, :arel, :builder_params, :loaded_references, :db_data_index

    delegate :each, :size, :to => :to_a

    def initialize(model_class: nil, manager_ref: nil, association: nil, parent: nil, strategy: nil, saved: nil,
                   custom_save_block: nil, delete_method: nil, data_index: nil, data: nil, dependency_attributes: nil,
                   attributes_blacklist: nil, attributes_whitelist: nil, complete: nil, update_only: nil,
                   check_changed: nil, custom_manager_uuid: nil, custom_db_finder: nil, arel: nil, builder_params: {})
      @model_class           = model_class
      @manager_ref           = manager_ref || [:ems_ref]
      @custom_manager_uuid   = custom_manager_uuid
      @custom_db_finder      = custom_db_finder
      @association           = association || []
      @parent                = parent || nil
      @arel                  = arel
      @dependency_attributes = dependency_attributes || {}
      @data                  = data || []
      @data_index            = data_index || {}
      @saved                 = saved || false
      @strategy              = process_strategy(strategy)
      @delete_method         = delete_method || :destroy
      @custom_save_block     = custom_save_block
      @check_changed         = check_changed.nil? ? true : check_changed
      @internal_attributes   = [:__feedback_edge_set_parent]
      @complete              = complete.nil? ? true : complete
      @update_only           = update_only.nil? ? false : update_only
      @builder_params        = builder_params

      @attributes_blacklist             = Set.new
      @attributes_whitelist             = Set.new
      @transitive_dependency_attributes = Set.new
      @references                       = Set.new
      @loaded_references                = Set.new
      @db_data_index                    = nil
      @data_collection_finalized        = false

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
      when :local_db_cache_all
        self.data_collection_finalized = true
        self.saved = true
      when :local_db_find_references
        self.saved = true
      when :local_db_find_missing_references
      end
      strategy_name
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

    def data_collection_finalized?
      data_collection_finalized
    end

    def <<(inventory_object)
      unless data_index[inventory_object.manager_uuid]
        data_index[inventory_object.manager_uuid] = inventory_object
        data << inventory_object
      end
      self
    end
    alias push <<

    def object_index(object)
      index_array = manager_ref.map do |attribute|
        if object.respond_to?(:[])
          object[attribute].to_s
        else
          object.public_send(attribute).try(:id) || object.public_send(attribute).to_s
        end
      end
      stringify_reference(index_array)
    end

    def object_index_with_keys(keys, object)
      keys.map { |attribute| object.public_send(attribute).to_s }.join(stringify_joiner)
    end

    def stringify_joiner
      "__"
    end

    def stringify_reference(reference)
      reference.join(stringify_joiner)
    end

    def manager_ref_to_cols
      # Convert attributes from unique key to actual db cols
      manager_ref.map do |ref|
        association_to_foreign_key_mapping[ref] || ref
      end
    end

    def find_or_build(manager_uuid)
      raise "The uuid consists of #{manager_ref.size} attributes, please find_or_build_by method" if manager_ref.size > 1

      find_or_build_by(manager_ref.first => manager_uuid)
    end

    def find_or_build_by(manager_uuid_hash)
      if !manager_uuid_hash.keys.all? { |x| manager_ref.include?(x) } || manager_uuid_hash.keys.size != manager_ref.size
        raise "Allowed find_or_build_by keys are #{manager_ref}"
      end

      # Not using find by since if could take record from db, then any changes would be ignored, since such record will
      # not be stored to DB, maybe we should rethink this?
      data_index[object_index(manager_uuid_hash)] || build(manager_uuid_hash)
    end

    def find(manager_uuid)
      return if manager_uuid.nil?
      case strategy
      when :local_db_find_references, :local_db_cache_all
        find_in_db(manager_uuid)
      when :local_db_find_missing_references
        data_index[manager_uuid] || find_in_db(manager_uuid)
      else
        data_index[manager_uuid]
      end
    end

    def find_by(manager_uuid_hash)
      if !manager_uuid_hash.keys.all? { |x| manager_ref.include?(x) } || manager_uuid_hash.keys.size != manager_ref.size
        raise "Allowed find_by keys are #{manager_ref}"
      end
      find(object_index(manager_uuid_hash))
    end

    def lazy_find(manager_uuid, key: nil, default: nil)
      ::ManagerRefresh::InventoryObjectLazy.new(self, manager_uuid, :key => key, :default => default)
    end

    def inventory_object_class
      @inventory_object_class ||= Class.new(::ManagerRefresh::InventoryObject)
    end

    def new_inventory_object(hash)
      inventory_object_class.new(self, hash)
    end

    def build(hash)
      hash = hash.merge(builder_params)
      inventory_object = new_inventory_object(hash)
      push(inventory_object)
      inventory_object
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
      if model_class
        presence_validators = model_class.validators.detect { |x| x.kind_of? ActiveRecord::Validations::PresenceValidator }
      end
      # Attributes that has to be always on the entity, so attributes making unique index of the record + attributes
      # that have presence validation
      fixed_attributes = manager_ref
      fixed_attributes += presence_validators.attributes unless presence_validators.blank?
      fixed_attributes
    end

    # Returns all unique non saved fixed dependencies
    def fixed_dependencies
      fixed_attrs = fixed_attributes

      filtered_dependency_attributes.each_with_object(Set.new) do |(key, value), fixed_deps|
        fixed_deps.merge(value) if fixed_attrs.include?(key)
      end.reject(&:saved?)
    end

    # Returns all unique non saved dependencies
    def dependencies
      filtered_dependency_attributes.values.map(&:to_a).flatten.uniq.reject(&:saved?)
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
      self.class.new(:model_class           => model_class,
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

    def association_to_foreign_key_mapping
      return {} unless model_class

      @association_to_foreign_key_mapping ||= model_class.reflect_on_all_associations.each_with_object({}) do |x, obj|
        obj[x.name] = x.foreign_key
      end
    end

    def foreign_key_to_association_mapping
      return {} unless model_class

      @foreign_key_to_association_mapping ||= model_class.reflect_on_all_associations.each_with_object({}) do |x, obj|
        obj[x.foreign_key] = x.name
      end
    end

    def association_to_foreign_type_mapping
      return {} unless model_class

      @association_to_foreign_type_mapping ||= model_class.reflect_on_all_associations.each_with_object({}) do |x, obj|
        obj[x.name] = x.foreign_type if x.polymorphic?
      end
    end

    def foreign_type_to_association_mapping
      return {} unless model_class

      @foreign_type_to_association_mapping ||= model_class.reflect_on_all_associations.each_with_object({}) do |x, obj|
        obj[x.foreign_type] = x.name if x.polymorphic?
      end
    end

    def base_class_name
      return "" unless model_class

      @base_class_name ||= model_class.base_class.name
    end

    def to_s
      whitelist = ", whitelist: [#{attributes_whitelist.to_a.join(", ")}]" unless attributes_whitelist.blank?
      blacklist = ", blacklist: [#{attributes_blacklist.to_a.join(", ")}]" unless attributes_blacklist.blank?

      strategy_name = ", strategy: #{strategy}" if strategy

      name = model_class || association

      "InventoryCollection:<#{name}>#{whitelist}#{blacklist}#{strategy_name}"
    end

    def inspect
      to_s
    end

    def scan!
      data.each do |inventory_object|
        scan_inventory_object(inventory_object)
      end
    end

    def db_collection_for_comparison
      return arel unless arel.nil?
      parent.send(association)
    end

    private

    attr_writer :attributes_blacklist, :attributes_whitelist, :db_data_index, :references

    # Finds manager_uuid in the DB. Using a configured strategy we cache obtained data in the db_data_index, so the
    # same find will not hit database twice. Also if we use lazy_links and this is called when
    # data_collection_finalized?, we load all data from the DB, referenced by lazy_links, in one query.
    #
    # @param manager_uuid [String] a manager_uuid of the InventoryObject we search in the local DB
    def find_in_db(manager_uuid)
      # TODO(lsmola) selected need to contain also :keys used in other InventoryCollections pointing to this one, once
      # we get list of all keys for each InventoryCollection ,we can uncomnent
      # selected   = [:id] + manager_ref.map { |x| model_class.reflect_on_association(x).try(:foreign_key) || x }
      # selected << :type if model_class.new.respond_to? :type
      # load_from_db.select(selected).find_each do |record|

      # Use the cached db_data_index only data_collection_finalized?, meaning no new reference can occur
      if data_collection_finalized? && db_data_index
        return db_data_index[manager_uuid]
      else
        return db_data_index[manager_uuid] if db_data_index && db_data_index[manager_uuid]
        # We haven't found the reference, lets add it to the list of references and load it
        references << manager_uuid unless references.include?(manager_uuid) # O(C) since references is Set
      end

      populate_db_data_index!

      db_data_index[manager_uuid]
    end

    # Fills db_data_index with InventoryObjects obtained from the DB
    def populate_db_data_index!
      # Load only new references from the DB
      new_references = references - loaded_references
      # And store which references we've already loaded
      loaded_references.merge(new_references)

      # Initialize db_data_index in nil
      self.db_data_index ||= {}

      # Return the the correct relation based on strategy and selection&projection
      case strategy
      when :local_db_cache_all
        selection  = nil
        projection = nil
      else
        selection  = extract_references(new_references)
        projection = nil
      end

      db_relation(selection, projection).find_each do |record|
        process_db_record!(record)
      end
    end

    # Return a Rails relation or array that will be used to obtain the records we need to load from the DB
    #
    # @param selection [Hash] A selection hash resulting in Select operation (in Relation algebra terms)
    # @param projection [Array] A projection array resulting in Project operation (in Relation algebra terms)
    def db_relation(selection = nil, projection = nil)
      relation = if !custom_db_finder.blank?
                   custom_db_finder.call(self, selection, projection)
                 else
                   rel = if !parent.nil? && !association.nil?
                           parent.send(association)
                         elsif !arel.nil?
                           arel
                         end
                   rel = rel.where(selection) if rel && selection
                   rel
                 end

      relation || []
    end

    # Extracting references to a relation friendly format, or a format processable by a custom_db_finder
    #
    # @param new_references [Array] array of manager_uuids of the InventoryObjects
    def extract_references(new_references = [])
      # We collect what manager_uuids of this IC were referenced and we load only those
      # TODO(lsmola) maybe in can be obj[x] = Set.new, since rails will do a query "col1 IN [a,b,b] AND col2 IN [e,f,e]"
      # which is equivalent to "col1 IN [a,b] AND col2 IN [e,f]". The best would be to forcing rails to query
      # "(col1, col2) IN [(a,e), (b,f), (b,e)]" which would load exactly what we need. Postgree supports this, but rails
      # doesn't seem to. So for now, we can load a bit more from the DB than we need, in case of manager_ref.count > 1
      hash_uuids_by_ref = manager_ref.each_with_object({}) { |x, obj| obj[x] = [] }

      # TODO(lsmola) hm, if we call find in the parser code, not all references will be here, so this will really work
      # only for lazy_find. So if we want to call find, I suppose we can cache all, possibly we could optimize this to
      # set references upfront?
      new_references.each do |reference|
        refs = reference.split(stringify_joiner)

        refs.each_with_index do |ref, index|
          hash_uuids_by_ref[manager_ref[index]] << ref
        end
      end
      hash_uuids_by_ref
    end

    # Takes ApplicationRecord record, converts it to the InventoryObject and places it to db_data_index
    #
    # @param record [ApplicationRecord] ApplicationRecord record we want to place to the db_data_index
    def process_db_record!(record)
      index = if custom_manager_uuid.nil?
                object_index(record)
              else
                stringify_reference(custom_manager_uuid.call(record))
              end
      db_data_index[index]    = new_inventory_object(record.attributes.symbolize_keys)
      db_data_index[index].id = record.id
    end

    def scan_inventory_object(inventory_object)
      inventory_object.data.each do |key, value|
        if value.kind_of?(Array)
          value.each { |val| scan_inventory_object_attribute(key, val) }
        else
          scan_inventory_object_attribute(key, value)
        end
      end
    end

    def scan_inventory_object_attribute(key, value)
      return unless inventory_object?(value)

      # Storing attributes and their dependencies
      (dependency_attributes[key] ||= Set.new) << value.inventory_collection if value.dependency?

      # Storing if attribute is a transitive dependency, so a lazy_find :key results in dependency
      transitive_dependency_attributes << key if transitive_dependency?(value)

      # Storing a reference in the target inventory_collection, then each IC knows about all the references and can
      # e.g. load all the referenced uuids from a DB
      value.inventory_collection.references << value.to_s
    end

    def inventory_object?(value)
      value.kind_of?(::ManagerRefresh::InventoryObjectLazy) || value.kind_of?(::ManagerRefresh::InventoryObject)
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
          if custom_manager_uuid.nil?
            raise "The unique key list manager_ref contains a reference, which can't be built automatically when loading"\
                  " the InventoryCollection from the DB, you need to provide a custom_manager_uuid lambda, that builds"\
                  " the correct manager_uuid given a DB record"
          end
        end
      end
    end

    def association_attributes
      # All association attributes and foreign keys of the model class
      model_class.reflect_on_all_associations.map { |x| [x.name, x.foreign_key] }.flatten.compact.map(&:to_sym)
    end
  end
end
