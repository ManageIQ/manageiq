module ManagerRefresh
  class InventoryCollection
    attr_accessor :saved, :references, :attribute_references, :data_collection_finalized

    attr_reader :model_class, :strategy, :attributes_blacklist, :attributes_whitelist, :custom_save_block, :parent,
                :internal_attributes, :delete_method, :data, :data_index, :dependency_attributes, :manager_ref,
                :association, :complete, :update_only, :transitive_dependency_attributes, :custom_manager_uuid,
                :custom_db_finder, :check_changed, :arel, :builder_params, :loaded_references, :db_data_index,
                :inventory_object_attributes, :name

    delegate :each, :size, :to => :to_a

    # Usage:
    ####################################################################################################################
    # Example 1, storing Vm model data into the DB:
    ####################################################################################################################
    #   ################################################################################################################
    #   # Example 1.1 Starting with no vms, lets add vm1 and vm2
    #   @ems = ManageIQ::Providers::BaseManager.first
    #   puts @ems.vms.collect(&:ems_ref) # => []
    #   # Init InventoryCollection
    #   vms_inventory_collection = ::ManagerRefresh::InventoryCollection.new(
    #     :model_class => ManageIQ::Providers::CloudManager::Vm, :parent => @ems, :association => :vms
    #   )
    #
    #   # Fill InventoryCollection with data
    #   vms_inventory_collection.build(:ems_ref => "vm1", :name => "vm1")
    #   vms_inventory_collection.build(:ems_ref => "vm2", :name => "vm2")
    #
    #   # Save InventoryCollection to the db
    #   ManagerRefresh::SaveInventory.save_inventory(@ems, [vms_inventory_collection])
    #
    #   # The result in the DB is that vm1 and vm2 were created
    #   puts @ems.vms.collect(&:ems_ref) # => ["vm1", "vm2"]
    #
    #   ################################################################################################################
    #   # Example 1.2 In another refresh, vm1 does not exist anymore and vm3 was added
    #   # Init InventoryCollection
    #   vms_inventory_collection = ::ManagerRefresh::InventoryCollection.new(
    #     :model_class => ManageIQ::Providers::CloudManager::Vm, :parent => @ems, :association => :vms
    #   )
    #   # Fill InventoryCollection with data
    #   vms_inventory_collection.build(:ems_ref => "vm2", :name => "vm2")
    #   vms_inventory_collection.build(:ems_ref => "vm3", :name => "vm3")
    #
    #   # Save InventoryCollection to the db
    #   ManagerRefresh::SaveInventory.save_inventory(@ems, [vms_inventory_collection])
    #
    #   # The result in the DB is that vm1 was deleted, vm2 was updated and vm3 was created
    #   puts @ems.vms.collect(&:ems_ref) # => ["vm2", "vm3"]
    #
    ####################################################################################################################
    #
    # For more usage examples please follow spec examples in:
    # spec/models/manager_refresh/save_inventory/single_inventory_collection_spec.rb
    # spec/models/manager_refresh/save_inventory/acyclic_graph_of_inventory_collections_spec.rb
    # spec/models/manager_refresh/save_inventory/graph_of_inventory_collections_spec.rb
    # spec/models/manager_refresh/save_inventory/graph_of_inventory_collections_targeted_refresh_spec.rb
    # spec/models/manager_refresh/save_inventory/strategies_and_references_spec.rb
    #
    # @param model_class [Class] A class of an ApplicationRecord model, that we want to persist into the DB or load from
    #        the DB.
    # @param manager_ref [Array] Array of Symbols, that are keys of the InventoryObject's data, inserted into this
    #        InventoryCollection. Using these keys, we need to be able to uniquely identify each of the InventoryObject
    #        objects inside.
    # @param association [Symbol] A Rails association callable on a :parent attribute is used for comparing with the
    #        objects in the DB, to decide if the InventoryObjects will be created/deleted/updated or used for obtaining
    #        the data from a DB, if a DB strategy is used. It returns objects of the :model_class class or its sub STI.
    # @param parent [ApplicationRecord] An ApplicationRecord object that has a callable :association method returning
    #        the objects of a :model_class.
    # @param strategy [Symbol] A strategy of the InventoryCollection that will be used for saving/loading of the
    #        InventoryObject objects.
    #        Allowed strategies are:
    #         - nil => InventoryObject objects of the InventoryCollection will be saved to the DB, only these objects
    #                  will be referable from the other InventoryCollection objects.
    #         - :local_db_cache_all => Loads InventoryObject objects from the database, it loads all the objects that
    #                                  are a result of a [:custom_db_finder, <:parent>.<:association>, :arel] taking
    #                                  first defined in this order. This strategy will not save any objects in the DB.
    #         - :local_db_find_references => Loads InventoryObject objects from the database, it loads only objects that
    #                                        were referenced by the other InventoryCollections using a filtered result
    #                                        of a [:custom_db_finder, <:parent>.<:association>, :arel] taking first
    #                                        defined in this order. This strategy will not save any objects in the DB.
    #         - :local_db_find_missing_references => InventoryObject objects of the InventoryCollection will be saved to
    #                                                the DB. Then if we reference an object that is not present, it will
    #                                                load them from the db using :local_db_find_references strategy.
    # @param saved [Boolean] Says whether this collection is already saved into the DB , e.g. InventoryCollections with
    #        DB only strategy are marked as saved. This causes InventoryCollection not being a dependency for any other
    #        InventoryCollection, since it is already persisted into the DB.
    # @param custom_save_block [Proc] A custom lambda/proc for persisting in the DB, for cases where it's not enough
    #        to just save every InventoryObject inside by the defined rules and default saving algorithm.
    #
    #        Example1 - saving SomeModel in my own ineffective way :-) :
    #          custom_save = lambda do |_ems, inventory_collection|
    #            inventory_collection.each |inventory_object| do
    #              hash = inventory_object.attributes # Loads possible dependencies into saveable hash
    #              obj = SomeModel.find_by(:attr => hash[:attr]) # Note: doing find_by for many models produces N+1
    #                                                            # queries, avoid this, this is just a simple example :-)
    #              obj.update_attributes(hash) if obj
    #              obj ||= SomeModel.create(hash)
    #              inventory_object.id = obj.id # If this InventoryObject is referenced elsewhere, we need to store its
    #                                             primary key back to the InventoryObject
    #           end
    #
    #        Example2 - saving parent OrchestrationStack in a more effective way, than the default saving algorithm can
    #          achieve. Ancestry gem requires an ActiveRecord object for association and is not defined as a proper
    #          ActiveRecord association. That leads in N+1 queries in the default saving algorithm, so we can do better
    #          with custom saving for now. The InventoryCollection is defined as a custom dependencies processor,
    #          without its own :model_class and InventoryObjects inside:
    #            ManagerRefresh::InventoryCollection.new({
    #              :association       => :orchestration_stack_ancestry,
    #              :custom_save_block => orchestration_stack_ancestry_save_block,
    #              :dependency_attributes => {
    #                :orchestration_stacks           => [collections[:orchestration_stacks]],
    #                :orchestration_stacks_resources => [collections[:orchestration_stacks_resources]]
    #              }
    #            })
    #
    #          And the labmda is defined as:
    #            orchestration_stack_ancestry_save_block = lambda do |_ems, inventory_collection|
    #              stacks_inventory_collection = inventory_collection.dependency_attributes[:orchestration_stacks].try(:first)
    #
    #              return if stacks_inventory_collection.blank?
    #
    #              stacks_parents = stacks_inventory_collection.data.each_with_object({}) do |x, obj|
    #                parent_id = x.data[:parent].load.try(:id)
    #                obj[x.id] = parent_id if parent_id
    #              end
    #
    #              model_class = stacks_inventory_collection.model_class
    #
    #              stacks_parents_indexed = model_class
    #                                         .select([:id, :ancestry])
    #                                         .where(:id => stacks_parents.values).find_each.index_by(&:id)
    #
    #              model_class
    #                .select([:id, :ancestry])
    #                .where(:id => stacks_parents.keys).find_each do |stack|
    #                parent = stacks_parents_indexed[stacks_parents[stack.id]]
    #                stack.update_attribute(:parent, parent)
    #              end
    #            end
    # @param delete_method [Symbol] A delete method that will be used for deleting of the InventoryObject, if the
    #        object is marked for deletion. A default is :destroy, the instance method must be defined on the
    #        :model_class.
    # @param data_index [Hash] InventoryObject objects of the InventoryCollection indexed in a Hash by their
    #        :manager_ref.
    # @param data [Array] InventoryObject objects of the InventoryCollection in an Array
    # @param dependency_attributes [Hash] Manually defined dependencies of this InventoryCollection. We can use this
    #        by manually place the InventoryCollection into the graph, to make sure the saving is invoked after the
    #        dependencies were saved. The dependencies itself are InventoryCollection objects. For a common use-cases
    #        we do not need to define dependencies manually, since those are inferred automatically by scanning of the
    #        data.
    #
    #        Example:
    #          :dependency_attributes => {
    #            :orchestration_stacks           => [collections[:orchestration_stacks]],
    #            :orchestration_stacks_resources => [collections[:orchestration_stacks_resources]]
    #          }
    #        This example is used in Example2 of the <param custom_save_block> and it means that our :custom_save_block
    #        will be invoked after the InventoryCollection :orchestration_stacks and :orchestration_stacks_resources
    #        are saved.
    # @param attributes_blacklist [Array] Attributes we do not want to include into saving. We cannot blacklist an
    #        attribute that is needed for saving of the object.
    #        Note: attributes_blacklist is also used for internal resolving of the cycles in the graph.
    #
    #        Example:
    #          In the Example2 of the <param custom_save_block>, we have a custom saving code, that saves a :parent
    #          attribute of the OrchestrationStack. That means we don't want that attribute saved as a part of
    #          InventoryCollection for OrchestrationStack, so we would set :attributes_blacklist => [:parent]. Then the
    #          :parent will be ignored while saving.
    # @param attributes_whitelist [Array] Same usage as the :attributes_blacklist, but defining full set of attributes
    #        that should be saved. Attributes that are part of :manager_ref and needed validations are automatically
    #        added.
    # @param complete [Boolean] By default true, :complete is marking we are sending a complete dataset and therefore
    #        we can create/update/delete the InventoryObject objects. If :complete is false we will only do
    #        create/update without delete.
    # @param update_only [Boolean] By default false. If true we only update the InventoryObject objects, if false we do
    #        create/update/delete.
    # @param check_changed [Boolean] By default true. If true, before updating the InventoryObject, we call Rails
    #        'changed?' method. This can optimize speed of updates heavily, but it can fail to recognize the change for
    #        e.g. Ancestry and Relationship based columns. If false, we always update the InventoryObject.
    # @param custom_manager_uuid [Proc] A custom way of getting a unique :manager_uuid of the object using :manager_ref.
    #        In a complex cases, where part of the :manager_ref is another InventoryObject, we cannot infer the
    #        :manager_uuid, if it comes from the DB. In that case, we need to provide a way of getting the :manager_uuid
    #        from the DB.
    #
    #        Example:
    #          Given the InventoryCollection.new({
    #                      :model_class         => ::Hardware,
    #                      :manager_ref         => [:vm_or_template],
    #                      :association         => :hardwares,
    #                      :custom_manager_uuid => custom_manager_uuid
    #                    })
    #
    #          The :manager_ref => [:vm_or_template] points to another InventoryObject and we need to get a
    #          :manager_uuid of that object. But if InventoryCollection was loaded from the DB, we can access the
    #          :manager_uuid only by loading it from the DB as:
    #             custom_manager_uuid = lambda do |hardware|
    #               [hardware.vm_or_template.ems_ref]
    #             end
    #
    #          Note: make sure to combine this with :custom_db_finder, to avoid N+1 queries being done, which we can
    #          achieve by .includes(:vm_or_template). See Example in <param :custom_db_finder>.
    # @param custom_db_finder [Proc] A custom way of getting the InventoryCollection out of the DB in a case of any DB
    #        based strategy. This should be used in a case of complex query needed for e.g. targeted refresh or as an
    #        optimization for :custom_manager_uuid.

    #        Example, we solve N+1 issue from Example <param :custom_manager_uuid> as well as a selection used for
    #        targeted refresh getting Hardware object from the DB instead of the API:
    #          Having InventoryCollection.new({
    #                   :model_class         => ::Hardware,
    #                   :manager_ref         => [:vm_or_template],
    #                   :association         => :hardwares,
    #                   :custom_manager_uuid => custom_manager_uuid,
    #                   :custom_db_finder    => custom_db_finder
    #                 })
    #
    #          We need a custom_db_finder:
    #            custom_db_finder = lambda do |inventory_collection, selection, _projection|
    #              relation = inventory_collection.parent.send(inventory_collection.association)
    #                                             .includes(:vm_or_template)
    #                                             .references(:vm_or_template)
    #              relation = relation.where(:vms => {:ems_ref => selection[:vm_or_template]}) unless selection.blank?
    #              relation
    #            end
    #
    #          Which solved 2 things for us:
    #            First:
    #              hardware.vm_or_template.ems_ref in a :custom_manager_uuid doesn't do N+1 queries anymore. To handle
    #              just this problem, it would be enough to return
    #              inventory_collection.parent.send(inventory_collection.association).includes?(:vm_or_template)
    #            Second:
    #              We can use :local_db_find_references strategy on this inventory collection, which could not be used
    #              by default, since the selection needs a complex join, to be able to filter by the :vm_or_template
    #              ems_ref.
    #              We could still use a :local_db_cache_all strategy though, which doesn't do any selection and loads
    #              all :hardwares from the DB.
    # @param arel [ActiveRecord::Associations::CollectionProxy|Arel::SelectManager] Instead of :parent and :association
    #        we can provide Arel directly to say what records should be compared to check if InventoryObject will be
    #        doing create/update/delete.
    #
    #        Example:
    #          for a targeted refresh, we want to delete/update/create only a list of vms specified with a list of
    #          ems_refs:
    #            :arel => manager.vms.where(:ems_ref => manager_refs)
    #          Then we want to do the same for the hardwares of only those vms:
    #             :arel => manager.hardwares.joins(:vm_or_template).where(
    #               'vms' => {:ems_ref => manager_refs}
    #             )
    #          And etc. for the other Vm related records.
    # @param builder_params [Hash] A hash of an attributes that will be added to every inventory object created by
    #        inventory_collection.build(hash)
    #
    #        Example:
    #          Given the inventory_collection = InventoryCollection.new({
    #                      :model_class    => ::Vm,
    #                      :arel           => @ems.vms,
    #                      :builder_params => {:ems_id => 10}
    #                    })
    #          And building the inventory_object like:
    #            inventory_object = inventory_collection.build(:ems_ref => "vm_1", :name => "vm1")
    #          The inventory_object.data will look like:
    #            {:ems_ref => "vm_1", :name => "vm1", :ems_id => 10}
    # @param inventory_object_attributes [Array] Array of attribute names that will be exposed as readers/writers on the
    #        InventoryObject objects inside.
    #
    #        Example:
    #          Given the inventory_collection = InventoryCollection.new({
    #                      :model_class                 => ::Vm,
    #                      :arel                        => @ems.vms,
    #                      :inventory_object_attributes => [:name, :label]
    #                    })
    #           And building the inventory_object like:
    #             inventory_object = inventory_collection.build(:ems_ref => "vm1", :name => "vm1")
    #           We can use inventory_object_attributes as setters and getters:
    #             inventory_object.name = "Name"
    #             inventory_object.label = inventory_object.name
    #           Which would be equivalent to less nicer way:
    #             inventory_object[:name] = "Name"
    #             inventory_object[:label] = inventory_object[:name]
    #           So by using inventory_object_attributes, we will be guarding the allowed attributes and will have an
    #           explicit list of allowed attributes, that can be used also for documentation purposes.
    # @param name [Symbol] A unique name of the InventoryCollection under a Persister. If not provided, the :association
    #        attribute is used. Providing either :name or :association is mandatory.
    def initialize(model_class: nil, manager_ref: nil, association: nil, parent: nil, strategy: nil, saved: nil,
                   custom_save_block: nil, delete_method: nil, data_index: nil, data: nil, dependency_attributes: nil,
                   attributes_blacklist: nil, attributes_whitelist: nil, complete: nil, update_only: nil,
                   check_changed: nil, custom_manager_uuid: nil, custom_db_finder: nil, arel: nil, builder_params: {},
                   inventory_object_attributes: nil, name: nil)
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
      @name                  = name || association

      raise "You have to pass either :name or :association argument to .new of #{self}" if @name.blank?

      @inventory_object_attributes = inventory_object_attributes

      @attributes_blacklist             = Set.new
      @attributes_whitelist             = Set.new
      @transitive_dependency_attributes = Set.new
      @references                       = Set.new
      @attribute_references             = Set.new
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

    def from_raw_data(inventory_objects_data, available_inventory_collections)
      inventory_objects_data.each do |inventory_object_data|
        hash = inventory_object_data.each_with_object({}) do |(key, value), result|
          result[key.to_sym] = if value.kind_of?(Array)
                                 value.map { |x| from_raw_value(x, available_inventory_collections) }
                               else
                                 from_raw_value(value, available_inventory_collections)
                               end
        end
        build(hash)
      end
    end

    def from_raw_value(value, available_inventory_collections)
      if value.kind_of?(Hash) && (value['type'] || value[:type]) == "ManagerRefresh::InventoryObjectLazy"
        value.transform_keys!(&:to_s)
      end

      if value.kind_of?(Hash) && value['type'] == "ManagerRefresh::InventoryObjectLazy"
        inventory_collection = available_inventory_collections[value['inventory_collection_name'].try(:to_sym)]
        raise "Couldn't build lazy_link #{value} the inventory_collection_name was not found" if inventory_collection.blank?
        inventory_collection.lazy_find(value['ems_ref'], :key => value['key'], :default => value['default'])
      else
        value
      end
    end

    def to_raw_data
      data.map do |inventory_object|
        inventory_object.data.transform_values do |value|
          if inventory_object_lazy?(value)
            value.to_raw_lazy_relation
          elsif value.kind_of?(Array) && (inventory_object_lazy?(value.compact.first) || inventory_object?(value.compact.first))
            value.compact.map(&:to_raw_lazy_relation)
          elsif inventory_object?(value)
            value.to_raw_lazy_relation
          else
            value
          end
        end
      end
    end

    def process_strategy(strategy_name)
      return unless strategy_name

      case strategy_name
      when :local_db_cache_all
        self.data_collection_finalized = true
        self.saved = true
      when :local_db_find_references
        self.saved = true
      when :local_db_find_missing_references
      else
        raise "Unknown InventoryCollection strategy: :#{strategy_name}, allowed strategies are :local_db_cache_all, "\
              ":local_db_find_references and :local_db_find_missing_references."
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

    def supports_sti?
      @supports_sti_cache = model_class.column_names.include?("type") if @supports_sti_cache.nil?
      @supports_sti_cache
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
        manager_uuid.kind_of?(Hash) ? find_by(manager_uuid) : data_index[manager_uuid]
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
      @inventory_object_class ||= begin
        klass = Class.new(::ManagerRefresh::InventoryObject)
        klass.add_attributes(inventory_object_attributes) if inventory_object_attributes
        klass
      end
    end

    def new_inventory_object(hash)
      manager_ref.each do |x|
        # TODO(lsmola) with some effort, we can do this, but it's complex
        raise "A lazy_find with a :key can't be a part of the manager_uuid" if inventory_object_lazy?(hash[x]) && hash[x].key
      end

      inventory_object_class.new(self, hash)
    end

    def build(hash)
      hash = builder_params.merge(hash)
      inventory_object = new_inventory_object(hash)

      uuid = inventory_object.manager_uuid
      # Each InventoryObject must be able to build an UUID, return nil if it can't
      return nil if uuid.blank?
      # Return existing InventoryObject if we have it
      return data_index[uuid] if data_index[uuid]
      # Store new InventoryObject and return it
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

    def belongs_to_associations
      model_class.reflect_on_all_associations.select { |x| x.kind_of? ActiveRecord::Reflection::BelongsToReflection }
    end

    def association_to_foreign_key_mapping
      return {} unless model_class

      @association_to_foreign_key_mapping ||= belongs_to_associations.each_with_object({}) do |x, obj|
        obj[x.name] = x.foreign_key
      end
    end

    def foreign_key_to_association_mapping
      return {} unless model_class

      @foreign_key_to_association_mapping ||= belongs_to_associations.each_with_object({}) do |x, obj|
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

    def association_to_base_class_mapping
      return {} unless model_class

      @association_to_base_class_mapping ||= model_class.reflect_on_all_associations.each_with_object({}) do |x, obj|
        obj[x.name] = x.klass.base_class.name unless x.polymorphic?
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
        scan_inventory_object!(inventory_object)
      end
    end

    def db_collection_for_comparison
      return arel unless arel.nil?
      parent.send(association)
    end

    private

    attr_writer :attributes_blacklist, :attributes_whitelist, :db_data_index

    # Finds manager_uuid in the DB. Using a configured strategy we cache obtained data in the db_data_index, so the
    # same find will not hit database twice. Also if we use lazy_links and this is called when
    # data_collection_finalized?, we load all data from the DB, referenced by lazy_links, in one query.
    #
    # @param manager_uuid [String] a manager_uuid of the InventoryObject we search in the local DB
    def find_in_db(manager_uuid)
      # Use the cached db_data_index only data_collection_finalized?, meaning no new reference can occur
      if data_collection_finalized? && db_data_index
        return db_data_index[manager_uuid]
      else
        return db_data_index[manager_uuid] if db_data_index && db_data_index[manager_uuid]
        # We haven't found the reference, lets add it to the list of references and load it
        references << manager_uuid unless references.include?(manager_uuid) # O(1) since references is Set
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

      # TODO(lsmola) selected need to contain also :keys used in other InventoryCollections pointing to this one, once
      # we get list of all keys for each InventoryCollection ,we can uncomnent
      # selected   = [:id] + manager_ref.map { |x| model_class.reflect_on_association(x).try(:foreign_key) || x }
      # selected << :type if model_class.new.respond_to? :type
      # load_from_db.select(selected).find_each do |record|

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
                   rel = rel.select(projection) if rel && projection
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

      attributes = record.attributes.symbolize_keys
      attribute_references.each do |ref|
        # We need to fill all references that are relations, we will use a ManagerRefresh::ApplicationRecordReference which
        # can be used for filling a relation and we don't need to do any query here
        # TODO(lsmola) maybe loading all, not just referenced here? Otherwise this will have issue for db_cache_all
        # and find used in parser
        next unless (foreign_key = association_to_foreign_key_mapping[ref])
        base_class_name = attributes[association_to_foreign_type_mapping[ref].try(:to_sym)] || association_to_base_class_mapping[ref]
        id              = attributes[foreign_key.to_sym]
        attributes[ref] = ManagerRefresh::ApplicationRecordReference.new(base_class_name, id)
      end

      db_data_index[index]    = new_inventory_object(attributes)
      db_data_index[index].id = record.id
    end

    def scan_inventory_object!(inventory_object)
      inventory_object.data.each do |key, value|
        if value.kind_of?(Array)
          value.each { |val| scan_inventory_object_attribute!(key, val) }
        else
          scan_inventory_object_attribute!(key, value)
        end
      end
    end

    def scan_inventory_object_attribute!(key, value)
      return if !inventory_object_lazy?(value) && !inventory_object?(value)

      # Storing attributes and their dependencies
      (dependency_attributes[key] ||= Set.new) << value.inventory_collection if value.dependency?

      # Storing a reference in the target inventory_collection, then each IC knows about all the references and can
      # e.g. load all the referenced uuids from a DB
      value.inventory_collection.references << value.to_s

      if inventory_object_lazy?(value)
        # Storing if attribute is a transitive dependency, so a lazy_find :key results in dependency
        transitive_dependency_attributes << key if value.transitive_dependency?

        # If we access an attribute of the value, using a :key, we want to keep a track of that
        value.inventory_collection.attribute_references << value.key if value.key
      end
    end

    def inventory_object?(value)
      value.kind_of?(::ManagerRefresh::InventoryObject)
    end

    def inventory_object_lazy?(value)
      value.kind_of?(::ManagerRefresh::InventoryObjectLazy)
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
