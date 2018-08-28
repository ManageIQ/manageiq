module ManagerRefresh
  # For more usage examples please follow spec examples in
  # * spec/models/manager_refresh/save_inventory/single_inventory_collection_spec.rb
  # * spec/models/manager_refresh/save_inventory/acyclic_graph_of_inventory_collections_spec.rb
  # * spec/models/manager_refresh/save_inventory/graph_of_inventory_collections_spec.rb
  # * spec/models/manager_refresh/save_inventory/graph_of_inventory_collections_targeted_refresh_spec.rb
  # * spec/models/manager_refresh/save_inventory/strategies_and_references_spec.rb
  #
  # @example storing Vm model data into the DB
  #
  #   @ems = ManageIQ::Providers::BaseManager.first
  #   puts @ems.vms.collect(&:ems_ref) # => []
  #
  #   # Init InventoryCollection
  #   vms_inventory_collection = ::ManagerRefresh::InventoryCollection.new(
  #     :model_class => ManageIQ::Providers::CloudManager::Vm, :parent => @ems, :association => :vms
  #   )
  #
  #   # Fill InventoryCollection with data
  #   # Starting with no vms, lets add vm1 and vm2
  #   vms_inventory_collection.build(:ems_ref => "vm1", :name => "vm1")
  #   vms_inventory_collection.build(:ems_ref => "vm2", :name => "vm2")
  #
  #   # Save InventoryCollection to the db
  #   ManagerRefresh::SaveInventory.save_inventory(@ems, [vms_inventory_collection])
  #
  #   # The result in the DB is that vm1 and vm2 were created
  #   puts @ems.vms.collect(&:ems_ref) # => ["vm1", "vm2"]
  #
  # @example In another refresh, vm1 does not exist anymore and vm3 was added
  #   # Init InventoryCollection
  #   vms_inventory_collection = ::ManagerRefresh::InventoryCollection.new(
  #     :model_class => ManageIQ::Providers::CloudManager::Vm, :parent => @ems, :association => :vms
  #   )
  #
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
  class InventoryCollection
    # @return [Boolean] A true value marks that we collected all the data of the InventoryCollection,
    #         meaning we also collected all the references.
    attr_accessor :data_collection_finalized

    # @return [ManagerRefresh::InventoryCollection::DataStorage] An InventoryCollection encapsulating all data with
    #         indexes
    attr_accessor :data_storage

    # @return [Boolean] true if this collection is already saved into the DB. E.g. InventoryCollections with
    #   DB only strategy are marked as saved. This causes InventoryCollection not being a dependency for any other
    #   InventoryCollection, since it is already persisted into the DB.
    attr_accessor :saved

    # If present, InventoryCollection switches into delete_complement mode, where it will
    # delete every record from the DB, that is not present in this list. This is used for the batch processing,
    # where we don't know which InventoryObject should be deleted, but we know all manager_uuids of all
    # InventoryObject objects that exists in the provider.
    #
    # @return [Array, nil] nil or a list of all :manager_uuids that are present in the Provider's InventoryCollection.
    attr_accessor :all_manager_uuids

    # @return [Set] A set of InventoryCollection objects that depends on this InventoryCollection object.
    attr_accessor :dependees

    # @return [Array<Symbol>] @see #parent_inventory_collections documentation of InventoryCollection.new kwargs
    #   parameters
    attr_accessor :parent_inventory_collections

    attr_reader :model_class, :strategy, :attributes_blacklist, :attributes_whitelist, :custom_save_block, :parent,
                :internal_attributes, :delete_method, :dependency_attributes, :manager_ref, :create_only,
                :association, :complete, :update_only, :transitive_dependency_attributes, :check_changed, :arel,
                :inventory_object_attributes, :name, :saver_strategy, :targeted_scope, :default_values,
                :targeted_arel, :targeted, :manager_ref_allowed_nil, :use_ar_object,
                :created_records, :updated_records, :deleted_records,
                :custom_reconnect_block, :batch_extra_attributes, :references_storage

    delegate :<<,
             :build,
             :build_partial,
             :data,
             :each,
             :find_or_build,
             :find_or_build_by,
             :from_hash,
             :index_proxy,
             :push,
             :size,
             :to_a,
             :to_hash,
             :to => :data_storage

    delegate :add_reference,
             :attribute_references,
             :build_reference,
             :references,
             :build_stringified_reference,
             :build_stringified_reference_for_record,
             :to => :references_storage

    delegate :find,
             :find_by,
             :lazy_find,
             :lazy_find_by,
             :named_ref,
             :primary_index,
             :reindex_secondary_indexes!,
             :skeletal_primary_index,
             :to => :index_proxy

    delegate :table_name,
             :to => :model_class

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
    #                                  are a result of a [<:parent>.<:association>, :arel] taking
    #                                  first defined in this order. This strategy will not save any objects in the DB.
    #         - :local_db_find_references => Loads InventoryObject objects from the database, it loads only objects that
    #                                        were referenced by the other InventoryCollections using a filtered result
    #                                        of a [<:parent>.<:association>, :arel] taking first
    #                                        defined in this order. This strategy will not save any objects in the DB.
    #         - :local_db_find_missing_references => InventoryObject objects of the InventoryCollection will be saved to
    #                                                the DB. Then if we reference an object that is not present, it will
    #                                                load them from the db using :local_db_find_references strategy.
    # @param custom_save_block [Proc] A custom lambda/proc for persisting in the DB, for cases where it's not enough
    #        to just save every InventoryObject inside by the defined rules and default saving algorithm.
    #
    #        Example1 - saving SomeModel in my own ineffective way :-) :
    #
    #            custom_save = lambda do |_ems, inventory_collection|
    #              inventory_collection.each |inventory_object| do
    #                hash = inventory_object.attributes # Loads possible dependencies into saveable hash
    #                obj = SomeModel.find_by(:attr => hash[:attr]) # Note: doing find_by for many models produces N+1
    #                                                              # queries, avoid this, this is just a simple example :-)
    #                obj.update_attributes(hash) if obj
    #                obj ||= SomeModel.create(hash)
    #                inventory_object.id = obj.id # If this InventoryObject is referenced elsewhere, we need to store its
    #                                               primary key back to the InventoryObject
    #             end
    #
    #        Example2 - saving parent OrchestrationStack in a more effective way, than the default saving algorithm can
    #        achieve. Ancestry gem requires an ActiveRecord object for association and is not defined as a proper
    #        ActiveRecord association. That leads in N+1 queries in the default saving algorithm, so we can do better
    #        with custom saving for now. The InventoryCollection is defined as a custom dependencies processor,
    #        without its own :model_class and InventoryObjects inside:
    #
    #            ManagerRefresh::InventoryCollection.new({
    #              :association       => :orchestration_stack_ancestry,
    #              :custom_save_block => orchestration_stack_ancestry_save_block,
    #              :dependency_attributes => {
    #                :orchestration_stacks           => [collections[:orchestration_stacks]],
    #                :orchestration_stacks_resources => [collections[:orchestration_stacks_resources]]
    #              }
    #            })
    #
    #        And the lambda is defined as:
    #
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
    # @param custom_reconnect_block [Proc] A custom lambda for reconnect logic of previously disconnected records
    #
    #        Example - Reconnect disconnected Vms
    #            ManagerRefresh::InventoryCollection.new({
    #              :association            => :orchestration_stack_ancestry,
    #              :custom_reconnect_block => vms_custom_reconnect_block,
    #            })
    #
    #        And the lambda is defined as:
    #
    #            vms_custom_reconnect_block = lambda do |inventory_collection, inventory_objects_index, attributes_index|
    #              inventory_objects_index.each_slice(1000) do |batch|
    #                Vm.where(:ems_ref => batch.map(&:second).map(&:manager_uuid)).each do |record|
    #                  index = inventory_collection.object_index_with_keys(inventory_collection.manager_ref_to_cols, record)
    #
    #                  # We need to delete the record from the inventory_objects_index and attributes_index, otherwise it
    #                  # would be sent for create.
    #                  inventory_object = inventory_objects_index.delete(index)
    #                  hash             = attributes_index.delete(index)
    #
    #                  record.assign_attributes(hash.except(:id, :type))
    #                  if !inventory_collection.check_changed? || record.changed?
    #                    record.save!
    #                    inventory_collection.store_updated_records(record)
    #                  end
    #
    #                  inventory_object.id = record.id
    #                end
    #              end
    # @param delete_method [Symbol] A delete method that will be used for deleting of the InventoryObject, if the
    #        object is marked for deletion. A default is :destroy, the instance method must be defined on the
    #        :model_class.
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
    #        In the Example2 of the <param custom_save_block>, we have a custom saving code, that saves a :parent
    #        attribute of the OrchestrationStack. That means we don't want that attribute saved as a part of
    #        InventoryCollection for OrchestrationStack, so we would set :attributes_blacklist => [:parent]. Then the
    #        :parent will be ignored while saving.
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
    # @param arel [ActiveRecord::Associations::CollectionProxy|Arel::SelectManager] Instead of :parent and :association
    #        we can provide Arel directly to say what records should be compared to check if InventoryObject will be
    #        doing create/update/delete.
    #
    #        Example:
    #        for a targeted refresh, we want to delete/update/create only a list of vms specified with a list of
    #        ems_refs:
    #            :arel => manager.vms.where(:ems_ref => manager_refs)
    #        Then we want to do the same for the hardwares of only those vms:
    #             :arel => manager.hardwares.joins(:vm_or_template).where(
    #               'vms' => {:ems_ref => manager_refs}
    #             )
    #        And etc. for the other Vm related records.
    # @param default_values [Hash] A hash of an attributes that will be added to every inventory object created by
    #        inventory_collection.build(hash)
    #
    #        Example: Given
    #          inventory_collection = InventoryCollection.new({
    #            :model_class    => ::Vm,
    #            :arel           => @ems.vms,
    #            :default_values => {:ems_id => 10}
    #          })
    #        And building the inventory_object like:
    #            inventory_object = inventory_collection.build(:ems_ref => "vm_1", :name => "vm1")
    #        The inventory_object.data will look like:
    #            {:ems_ref => "vm_1", :name => "vm1", :ems_id => 10}
    # @param inventory_object_attributes [Array] Array of attribute names that will be exposed as readers/writers on the
    #        InventoryObject objects inside.
    #
    #        Example: Given
    #                   inventory_collection = InventoryCollection.new({
    #                      :model_class                 => ::Vm,
    #                      :arel                        => @ems.vms,
    #                      :inventory_object_attributes => [:name, :label]
    #                    })
    #        And building the inventory_object like:
    #          inventory_object = inventory_collection.build(:ems_ref => "vm1", :name => "vm1")
    #        We can use inventory_object_attributes as setters and getters:
    #          inventory_object.name = "Name"
    #          inventory_object.label = inventory_object.name
    #        Which would be equivalent to less nicer way:
    #          inventory_object[:name] = "Name"
    #          inventory_object[:label] = inventory_object[:name]
    #        So by using inventory_object_attributes, we will be guarding the allowed attributes and will have an
    #        explicit list of allowed attributes, that can be used also for documentation purposes.
    # @param name [Symbol] A unique name of the InventoryCollection under a Persister. If not provided, the :association
    #        attribute is used. If :association is nil as well, the :name will be inferred from the :model_class.
    # @param saver_strategy [Symbol] A strategy that will be used for InventoryCollection persisting into the DB.
    #        Allowed saver strategies are:
    #        - :default => Using Rails saving methods, this way is not safe to run in multiple workers concurrently,
    #          since it will lead to non consistent data.
    #        - :batch => Using batch SQL queries, this way is not safe to run in multiple workers
    #          concurrently, since it will lead to non consistent data.
    #        - :concurrent_safe => This method is designed for concurrent saving. It uses atomic upsert to avoid
    #          data duplication and it uses timestamp based atomic checks to avoid new data being overwritten by the
    #          the old data.
    #        - :concurrent_safe_batch => Same as :concurrent_safe, but the upsert/update queries are executed as
    #          batched SQL queries, instead of sending 1 query per record.
    # @param parent_inventory_collections [Array] Array of symbols having a name pointing to the
    #        ManagerRefresh::InventoryCollection objects, that serve as parents to this InventoryCollection. There are
    #        several scenarios to consider, when deciding if InventoryCollection has parent collections, see the example.
    #
    #        Example:
    #          taking inventory collections :vms and :disks (local disks), if we write that:
    #          inventory_collection = InventoryCollection.new({
    #                       :model_class                 => ::Disk,
    #                       :association                 => :disks,
    #                       :manager_ref                 => [:vm, :location]
    #                       :parent_inventory_collection => [:vms],
    #                     })
    #
    #          Then the decision for having :parent_inventory_collection => [:vms] was probably driven by these
    #          points:
    #          1. We can get list of all disks only by doing SQL query through the parent object (so there will be join
    #             from vms to disks table).
    #          2. There is no API query for getting all disks from the provider API, we get them inside VM data, or as
    #             a Vm subquery
    #          3. Part of the manager_ref of the IC is the VM object (foreign key), so the disk's location is unique
    #             only under 1 Vm. (In current models, this modeled going through Hardware model)
    #          4. In targeted refresh, we always expect that each Vm will be saved with all its disks.
    #
    #          Then having the above points, adding :parent_inventory_collection => [:vms], will bring these
    #          implications:
    #          1. By archiving/deleting Vm, we can no longer see the disk, because those were owned by the Vm. Any
    #             archival/deletion of the Disk model, must be then done by cascade delete/hooks logic.
    #          2. Having Vm as a parent ensures we always process it first. So e.g. when providing no Vms for saving
    #             we would have no graph dependency (no data --> no edges --> no dependencies) and Disk could be
    #             archived/removed before the Vm, while we always want to archive the VM first.
    #          3. For targeted refresh, we always expect that all disks are saved with a VM. So for targeting :disks,
    #             we are not using #manager_uuids attribute, since the scope is "all disks of all targeted VMs", so we
    #             always use #manager_uuids of the parent. (that is why :parent_inventory_collections and
    #             :manager_uuids are mutually exclusive attributes)
    #          4. For automatically building the #targeted_arel query, we need the parent to know what is the root node.
    #             While this information can be introspected from the data, it creates a scope for create&update&delete,
    #             which means it has to work with no data provided (causing delete all). So with no data we cannot
    #             introspect anything.
    # @param manager_uuids [Array|Proc] Array of manager_uuids of the InventoryObjects we want to create/update/delete. Using
    #        this attribute, the db_collection_for_comparison will be automatically limited by the manager_uuids, in a
    #        case of a simple relation. In a case of a complex relation, we can leverage :manager_uuids in a
    #        custom :targeted_arel. We can pass also lambda, for lazy_evaluation.
    # @param all_manager_uuids [Array] Array of all manager_uuids of the InventoryObjects. With the :targeted true,
    #        having this parameter defined will invoke only :delete_method on a complement of this set, making sure
    #        the DB has only this set of data after. This :attribute serves for deleting of top level
    #        InventoryCollections, i.e. InventoryCollections having parent_inventory_collections nil. The deleting of
    #        child collections is already handled by the scope of the parent_inventory_collections and using Rails
    #        :dependent => :destroy,
    # @param targeted_arel [Proc] A callable block that receives this InventoryCollection as a first argument. In there
    #        we can leverage a :parent_inventory_collections or :manager_uuids to limit the query based on the
    #        manager_uuids available.
    #        Example:
    #          targeted_arel = lambda do |inventory_collection|
    #            # Getting ems_refs of parent :vms and :miq_templates
    #            manager_uuids = inventory_collection.parent_inventory_collections.collect(&:manager_uuids).flatten
    #            inventory_collection.db_collection_for_comparison.hardwares.joins(:vm_or_template).where(
    #              'vms' => {:ems_ref => manager_uuids}
    #            )
    #          end
    #
    #          inventory_collection = InventoryCollection.new({
    #                                   :model_class                 => ::Hardware,
    #                                   :association                 => :hardwares,
    #                                   :parent_inventory_collection => [:vms, :miq_templates],
    #                                   :targeted_arel               => targeted_arel,
    #                                 })
    # @param targeted [Boolean] True if the collection is targeted, in that case it will be leveraging :manager_uuids
    #        :parent_inventory_collections and :targeted_arel to save a subgraph of a data.
    # @param manager_ref_allowed_nil [Array] Array of symbols having manager_ref columns, that are a foreign key an can
    #        be nil. Given the table are shared by many providers, it can happen, that the table is used only partially.
    #        Then it can happen we want to allow certain foreign keys to be nil, while being sure the referential
    #        integrity is not broken. Of course the DB Foreign Key can't be created in this case, so we should try to
    #        avoid this usecase by a proper modeling.
    # @param use_ar_object [Boolean] True or False. Whether we need to initialize AR object as part of the saving
    #        it's needed if the model have special setters, serialize of columns, etc. This setting is relevant only
    #        for the batch saver strategy.
    # @param batch_extra_attributes [Array] Array of symbols marking which extra attributes we want to store into the
    #        db. These extra attributes might be a product of :use_ar_object assignment and we need to specify them
    #        manually, if we want to use a batch saving strategy and we have models that populate attributes as a side
    #        effect.
    def initialize(model_class: nil, manager_ref: nil, association: nil, parent: nil, strategy: nil,
                   custom_save_block: nil, delete_method: nil, dependency_attributes: nil,
                   attributes_blacklist: nil, attributes_whitelist: nil, complete: nil, update_only: nil,
                   check_changed: nil, arel: nil, default_values: {}, create_only: nil,
                   inventory_object_attributes: nil, name: nil, saver_strategy: nil,
                   parent_inventory_collections: nil, manager_uuids: [], all_manager_uuids: nil, targeted_arel: nil,
                   targeted: nil, manager_ref_allowed_nil: nil, secondary_refs: {}, use_ar_object: nil,
                   custom_reconnect_block: nil, batch_extra_attributes: [])
      @model_class            = model_class
      @manager_ref            = manager_ref || [:ems_ref]
      @secondary_refs         = secondary_refs
      @association            = association
      @parent                 = parent || nil
      @arel                   = arel
      @dependency_attributes  = dependency_attributes || {}
      @strategy               = process_strategy(strategy)
      @delete_method          = delete_method || :destroy
      @custom_save_block      = custom_save_block
      @custom_reconnect_block = custom_reconnect_block
      @check_changed          = check_changed.nil? ? true : check_changed
      @internal_attributes    = %i(__feedback_edge_set_parent __parent_inventory_collections)
      @complete               = complete.nil? ? true : complete
      @update_only            = update_only.nil? ? false : update_only
      @create_only            = create_only.nil? ? false : create_only
      @default_values         = default_values
      @name                   = name || association || model_class.to_s.demodulize.tableize
      @saver_strategy         = process_saver_strategy(saver_strategy)
      @use_ar_object          = use_ar_object || false
      @batch_extra_attributes = batch_extra_attributes

      @manager_ref_allowed_nil = manager_ref_allowed_nil || []

      # Targeted mode related attributes
      # TODO(lsmola) Should we refactor this to use references too?
      @all_manager_uuids            = all_manager_uuids
      @parent_inventory_collections = parent_inventory_collections
      @targeted_arel                = targeted_arel
      @targeted                     = !!targeted

      @inventory_object_attributes = inventory_object_attributes

      @saved                          ||= false
      @attributes_blacklist             = Set.new
      @attributes_whitelist             = Set.new
      @transitive_dependency_attributes = Set.new
      @dependees                        = Set.new
      @data_storage = ::ManagerRefresh::InventoryCollection::DataStorage.new(self, secondary_refs)
      @references_storage = ::ManagerRefresh::InventoryCollection::ReferencesStorage.new(index_proxy)
      @targeted_scope = ::ManagerRefresh::InventoryCollection::ReferencesStorage.new(index_proxy).merge!(manager_uuids)

      @created_records = []
      @updated_records = []
      @deleted_records = []

      blacklist_attributes!(attributes_blacklist) if attributes_blacklist.present?
      whitelist_attributes!(attributes_whitelist) if attributes_whitelist.present?
    end

    # Caches what records were created, for later use, e.g. post provision behavior
    #
    # @param records [Array<ApplicationRecord, Hash>] list of stored records
    def store_created_records(records)
      @created_records.concat(records_identities(records))
    end

    # Caches what records were updated, for later use, e.g. post provision behavior
    #
    # @param records [Array<ApplicationRecord, Hash>] list of stored records
    def store_updated_records(records)
      @updated_records.concat(records_identities(records))
    end

    # Caches what records were deleted/soft-deleted, for later use, e.g. post provision behavior
    #
    # @param records [Array<ApplicationRecord, Hash>] list of stored records
    def store_deleted_records(records)
      @deleted_records.concat(records_identities(records))
    end

    # Processes passed saver strategy
    #
    # @param saver_strategy [Symbol] Passed saver strategy
    # @return [Symbol] Returns back the passed strategy if supported, or raises exception
    def process_saver_strategy(saver_strategy)
      return :default unless saver_strategy

      saver_strategy = saver_strategy.to_sym
      case saver_strategy
      when :default, :batch, :concurrent_safe, :concurrent_safe_batch
        saver_strategy
      else
        raise "Unknown InventoryCollection saver strategy: :#{saver_strategy}, allowed strategies are "\
              ":default, :batch, :concurrent_safe and :concurrent_safe_batch"
      end
    end

    # Processes passed strategy, modifies :data_collection_finalized and :saved attributes for db only strategies
    #
    # @param strategy_name [Symbol] Passed saver strategy
    # @return [Symbol] Returns back the passed strategy if supported, or raises exception
    def process_strategy(strategy_name)
      self.data_collection_finalized = false

      return unless strategy_name

      strategy_name = strategy_name.to_sym
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

    # @return [Boolean] true means we want to call .changed? on every ActiveRecord object before saving it
    def check_changed?
      check_changed
    end

    # @return [Boolean] true means we want to use ActiveRecord object for writing attributes and we want to perform
    #         casting on all columns
    def use_ar_object?
      use_ar_object
    end

    # @return [Boolean] true means the data is not complete, leading to only creating and updating data
    def complete?
      complete
    end

    # @return [Boolean] true means we want to only update data
    def update_only?
      update_only
    end

    # @return [Boolean] true means we will delete/soft-delete data
    def delete_allowed?
      complete? && !update_only?
    end

    # @return [Boolean] true means we will delete/soft-delete data
    def create_allowed?
      !update_only?
    end

    # @return [Boolean] true means that only create of new data is allowed
    def create_only?
      create_only
    end

    # @return [Boolean] true if the whole InventoryCollection object has all data persisted
    def saved?
      saved
    end

    # @return [Boolean] true if all dependencies have all data persisted
    def saveable?
      dependencies.all?(&:saved?)
    end

    # @return [Boolean] true if we are using a saver strategy that allows saving in parallel processes
    def parallel_safe?
      @parallel_safe_cache ||= %i(concurrent_safe concurrent_safe_batch).include?(saver_strategy)
    end

    # @return [Boolean] true if the model_class supports STI
    def supports_sti?
      @supports_sti_cache = model_class.column_names.include?("type") if @supports_sti_cache.nil?
      @supports_sti_cache
    end

    # @return [Boolean] true if the model_class has created_on column
    def supports_created_on?
      if @supports_created_on_cache.nil?
        @supports_created_on_cache = (model_class.column_names.include?("created_on") && ActiveRecord::Base.record_timestamps)
      end
      @supports_created_on_cache
    end

    # @return [Boolean] true if the model_class has updated_on column
    def supports_updated_on?
      if @supports_updated_on_cache.nil?
        @supports_updated_on_cache = (model_class.column_names.include?("updated_on") && ActiveRecord::Base.record_timestamps)
      end
      @supports_updated_on_cache
    end

    # @return [Boolean] true if the model_class has created_at column
    def supports_created_at?
      if @supports_created_at_cache.nil?
        @supports_created_at_cache = (model_class.column_names.include?("created_at") && ActiveRecord::Base.record_timestamps)
      end
      @supports_created_at_cache
    end

    # @return [Boolean] true if the model_class has updated_at column
    def supports_updated_at?
      if @supports_updated_at_cache.nil?
        @supports_updated_at_cache = (model_class.column_names.include?("updated_at") && ActiveRecord::Base.record_timestamps)
      end
      @supports_updated_at_cache
    end

    # @return [Boolean] true if the model_class has resource_timestamps_max column
    def supports_resource_timestamps_max?
      @supports_resource_timestamps_max_cache ||= model_class.column_names.include?("resource_timestamps_max")
    end

    # @return [Boolean] true if the model_class has resource_timestamps column
    def supports_resource_timestamps?
      @supports_resource_timestamps_cache ||= model_class.column_names.include?("resource_timestamps")
    end

    # @return [Boolean] true if the model_class has resource_timestamp column
    def supports_resource_timestamp?
      @supports_resource_timestamp_cache ||= model_class.column_names.include?("resource_timestamp")
    end

    # @return [Boolean] true if the model_class has resource_versions_max column
    def supports_resource_versions_max?
      @supports_resource_versions_max_cache ||= model_class.column_names.include?("resource_versions_max")
    end

    # @return [Boolean] true if the model_class has resource_versions column
    def supports_resource_versions?
      @supports_resource_versions_cache ||= model_class.column_names.include?("resource_versions")
    end

    # @return [Boolean] true if the model_class has resource_version column
    def supports_resource_version?
      @supports_resource_version_cache ||= model_class.column_names.include?("resource_version")
    end

    # @return [Array<Symbol>] all columns that are part of the best fit unique index
    def unique_index_columns
      return @unique_index_columns if @unique_index_columns

      @unique_index_columns = unique_index_for(unique_index_keys).columns.map(&:to_sym)
    end

    def unique_index_keys
      @unique_index_keys ||= manager_ref_to_cols.map(&:to_sym)
    end

    # @return [Array<ActiveRecord::ConnectionAdapters::IndexDefinition>] array of all unique indexes known to model
    def unique_indexes
      @unique_indexes_cache if @unique_indexes_cache

      @unique_indexes_cache = model_class.connection.indexes(model_class.table_name).select(&:unique)

      if @unique_indexes_cache.blank?
        raise "#{self} and its table #{model_class.table_name} must have a unique index defined, to"\
                " be able to use saver_strategy :concurrent_safe or :concurrent_safe_batch."
      end

      @unique_indexes_cache
    end

    # Finds an index that fits the list of columns (keys) the best
    #
    # @param keys [Array<Symbol>]
    # @raise [Exception] if the unique index for the columns was not found
    # @return [ActiveRecord::ConnectionAdapters::IndexDefinition] unique index fitting the keys
    def unique_index_for(keys)
      @unique_index_for_keys_cache ||= {}
      @unique_index_for_keys_cache[keys] if @unique_index_for_keys_cache[keys]

      # Find all uniq indexes that that are covering our keys
      uniq_key_candidates = unique_indexes.each_with_object([]) { |i, obj| obj << i if (keys - i.columns.map(&:to_sym)).empty? }

      if @unique_indexes_cache.blank?
        raise "#{self} and its table #{model_class.table_name} must have a unique index defined "\
                "covering columns #{keys} to be able to use saver_strategy :concurrent_safe or :concurrent_safe_batch."
      end

      # Take the uniq key having the least number of columns
      @unique_index_for_keys_cache[keys] = uniq_key_candidates.min_by { |x| x.columns.count }
    end

    def internal_columns
      return @internal_columns if @internal_columns

      @internal_columns = [] + internal_timestamp_columns
      @internal_columns << :type if supports_sti?
      @internal_columns << :resource_timestamps_max if supports_resource_timestamps_max?
      @internal_columns << :resource_timestamps if supports_resource_timestamps?
      @internal_columns << :resource_timestamp if supports_resource_timestamp?
      @internal_columns << :resource_versions_max if supports_resource_versions_max?
      @internal_columns << :resource_versions if supports_resource_versions?
      @internal_columns << :resource_version if supports_resource_version?
      @internal_columns
    end

    def internal_timestamp_columns
      return @internal_timestamp_columns if @internal_timestamp_columns

      @internal_timestamp_columns = []
      @internal_timestamp_columns << :created_on if supports_created_on?
      @internal_timestamp_columns << :created_at if supports_created_at?
      @internal_timestamp_columns << :updated_on if supports_updated_on?
      @internal_timestamp_columns << :updated_at if supports_updated_at?

      @internal_timestamp_columns
    end

    def base_columns
      @base_columns ||= unique_index_columns + internal_columns
    end

    # @return [Boolean] true if no more data will be added to this InventoryCollection object, that usually happens
    #         after the parsing step is finished
    def data_collection_finalized?
      data_collection_finalized
    end

    # @param value [Object] Object we want to test
    # @return [Boolean] true is value is kind of ManagerRefresh::InventoryObject
    def inventory_object?(value)
      value.kind_of?(::ManagerRefresh::InventoryObject)
    end

    # @param value [Object] Object we want to test
    # @return [Boolean] true is value is kind of ManagerRefresh::InventoryObjectLazy
    def inventory_object_lazy?(value)
      value.kind_of?(::ManagerRefresh::InventoryObjectLazy)
    end

    # Builds string uuid from passed Object and keys
    #
    # @param keys [Array<Symbol>] Indexes into the Hash data
    # @param record [ApplicationRecord] ActiveRecord record
    # @return [String] Concatenated values on keys from data
    def object_index_with_keys(keys, record)
      # TODO(lsmola) remove, last usage is in k8s reconnect logic
      build_stringified_reference_for_record(record, keys)
    end

    # True if processing of this InventoryCollection object would lead to no operations. Then we use this marker to
    # stop processing of the InventoryCollector object very soon, to avoid a lot of unnecessary Db queries, etc.
    #
    # @return [Boolean] true if processing of this InventoryCollection object would lead to no operations.
    def noop?
      # If this InventoryCollection doesn't do anything. it can easily happen for targeted/batched strategies.
      if targeted?
        if parent_inventory_collections.nil? && targeted_scope.primary_references.blank? &&
           all_manager_uuids.nil? && parent_inventory_collections.blank? && custom_save_block.nil? &&
           skeletal_primary_index.blank?
          # It's a noop Parent targeted InventoryCollection
          true
        elsif !parent_inventory_collections.nil? && parent_inventory_collections.all? { |x| x.targeted_scope.primary_references.blank? } &&
              skeletal_primary_index.blank?
          # It's a noop Child targeted InventoryCollection
          true
        else
          false
        end
      elsif data.blank? && !delete_allowed? && skeletal_primary_index.blank?
        # If we have no data to save and delete is not allowed, we can just skip
        true
      else
        false
      end
    end

    # @return [Boolean] true is processing of this InventoryCollection will be in targeted mode
    def targeted?
      targeted
    end

    # Convert manager_ref list of attributes to list of DB columns
    #
    # @return [Array<String>] true is processing of this InventoryCollection will be in targeted mode
    def manager_ref_to_cols
      # TODO(lsmola) this should contain the polymorphic _type, otherwise the IC with polymorphic unique key will get
      # conflicts
      manager_ref.map do |ref|
        association_to_foreign_key_mapping[ref] || ref
      end
    end

    # List attributes causing a dependency and filters them by attributes_blacklist and attributes_whitelist
    #
    # @return [Hash{Symbol => Set}] attributes causing a dependency and filtered by blacklist and whitelist
    def filtered_dependency_attributes
      filtered_attributes = dependency_attributes

      if attributes_blacklist.present?
        filtered_attributes = filtered_attributes.reject { |key, _value| attributes_blacklist.include?(key) }
      end

      if attributes_whitelist.present?
        filtered_attributes = filtered_attributes.select { |key, _value| attributes_whitelist.include?(key) }
      end

      filtered_attributes
    end

    # Attributes that are needed to be able to save the record, i.e. attributes that are part of the unique index
    # and attributes with presence validation or NOT NULL constraint
    #
    # @return [Array<Symbol>] attributes that are needed for saving of the record
    def fixed_attributes
      if model_class
        presence_validators = model_class.validators.detect { |x| x.kind_of?(ActiveRecord::Validations::PresenceValidator) }
      end
      # Attributes that has to be always on the entity, so attributes making unique index of the record + attributes
      # that have presence validation
      fixed_attributes = manager_ref
      fixed_attributes += presence_validators.attributes if presence_validators.present?
      fixed_attributes
    end

    # Returns fixed dependencies, which are the ones we can't move, because we wouldn't be able to save the data
    #
    # @returns [Set<ManagerRefresh::InventoryCollection>] all unique non saved fixed dependencies
    def fixed_dependencies
      fixed_attrs = fixed_attributes

      filtered_dependency_attributes.each_with_object(Set.new) do |(key, value), fixed_deps|
        fixed_deps.merge(value) if fixed_attrs.include?(key)
      end.reject(&:saved?)
    end

    # @return [Array<ManagerRefresh::InventoryCollection>] all unique non saved dependencies
    def dependencies
      filtered_dependency_attributes.values.map(&:to_a).flatten.uniq.reject(&:saved?)
    end

    # Returns what attributes are causing a dependencies to certain InventoryCollection objects.
    #
    # @param inventory_collections [Array<ManagerRefresh::InventoryCollection>]
    # @return [Array<ManagerRefresh::InventoryCollection>] attributes causing the dependencies to certain
    #         InventoryCollection objects
    def dependency_attributes_for(inventory_collections)
      attributes = Set.new
      inventory_collections.each do |inventory_collection|
        attributes += filtered_dependency_attributes.select { |_key, value| value.include?(inventory_collection) }.keys
      end
      attributes
    end

    # Add passed attributes to blacklist. The manager_ref attributes cannot be blacklisted, otherwise we will not
    # be able to identify the inventory_object. We do not automatically remove attributes causing fixed dependencies,
    # so beware that without them, you won't be able to create the record.
    #
    # @param attributes [Array<Symbol>] Attributes we want to blacklist
    # @return [Array<Symbol>] All blacklisted attributes
    def blacklist_attributes!(attributes)
      self.attributes_blacklist += attributes - (fixed_attributes + internal_attributes)
    end

    # Add passed attributes to whitelist. The manager_ref attributes always needs to be in the white list, otherwise
    # we will not be able to identify theinventory_object. We do not automatically add attributes causing fixed
    # dependencies, so beware that without them, you won't be able to create the record.
    #
    # @param attributes [Array<Symbol>] Attributes we want to whitelist
    # @return [Array<Symbol>] All whitelisted attributes
    def whitelist_attributes!(attributes)
      self.attributes_whitelist += attributes + (fixed_attributes + internal_attributes)
    end

    # @return [InventoryCollection] a shallow copy of InventoryCollection, the copy will share data_storage of the
    #         original collection, otherwise we would be copying a lot of records in memory.
    def clone
      cloned = self.class.new(:model_class           => model_class,
                              :manager_ref           => manager_ref,
                              :association           => association,
                              :parent                => parent,
                              :arel                  => arel,
                              :strategy              => strategy,
                              :saver_strategy        => saver_strategy,
                              :custom_save_block     => custom_save_block,
                              # We want cloned IC to be update only, since this is used for cycle resolution
                              :update_only           => true,
                              # Dependency attributes need to be a hard copy, since those will differ for each
                              # InventoryCollection
                              :dependency_attributes => dependency_attributes.clone)

      cloned.data_storage = data_storage
      cloned
    end

    # @return [Array<ActiveRecord::Reflection::BelongsToReflection">] All belongs_to associations
    def belongs_to_associations
      model_class.reflect_on_all_associations.select { |x| x.kind_of?(ActiveRecord::Reflection::BelongsToReflection) }
    end

    # @return [Hash{Symbol => String}] Hash with association name mapped to foreign key column name
    def association_to_foreign_key_mapping
      return {} unless model_class

      @association_to_foreign_key_mapping ||= belongs_to_associations.each_with_object({}) do |x, obj|
        obj[x.name] = x.foreign_key
      end
    end

    # @return [Hash{String => Hash}] Hash with foreign_key column name mapped to association name
    def foreign_key_to_association_mapping
      return {} unless model_class

      @foreign_key_to_association_mapping ||= belongs_to_associations.each_with_object({}) do |x, obj|
        obj[x.foreign_key] = x.name
      end
    end

    # @return [Hash{Symbol => String}] Hash with association name mapped to polymorphic foreign key type column name
    def association_to_foreign_type_mapping
      return {} unless model_class

      @association_to_foreign_type_mapping ||= model_class.reflect_on_all_associations.each_with_object({}) do |x, obj|
        obj[x.name] = x.foreign_type if x.polymorphic?
      end
    end

    # @return [Hash{Symbol => String}] Hash with polymorphic foreign key type column name mapped to association name
    def foreign_type_to_association_mapping
      return {} unless model_class

      @foreign_type_to_association_mapping ||= model_class.reflect_on_all_associations.each_with_object({}) do |x, obj|
        obj[x.foreign_type] = x.name if x.polymorphic?
      end
    end

    # @return [Hash{Symbol => String}] Hash with association name mapped to base class of the association
    def association_to_base_class_mapping
      return {} unless model_class

      @association_to_base_class_mapping ||= model_class.reflect_on_all_associations.each_with_object({}) do |x, obj|
        obj[x.name] = x.klass.base_class.name unless x.polymorphic?
      end
    end

    # @return [Array<Symbol>] List of all column names that are foreign keys
    def foreign_keys
      return [] unless model_class

      @foreign_keys_cache ||= belongs_to_associations.map(&:foreign_key).map!(&:to_sym)
    end

    # @return [Array<Symbol>] List of all column names that are foreign keys and cannot removed, otherwise we couldn't
    #         save the record
    def fixed_foreign_keys
      # Foreign keys that are part of a manager_ref must be present, otherwise the record would get lost. This is a
      # minimum check we can do to not break a referential integrity.
      return @fixed_foreign_keys_cache unless @fixed_foreign_keys_cache.nil?

      manager_ref_set = (manager_ref - manager_ref_allowed_nil)
      @fixed_foreign_keys_cache = manager_ref_set.map { |x| association_to_foreign_key_mapping[x] }.compact
      @fixed_foreign_keys_cache += foreign_keys & manager_ref
      @fixed_foreign_keys_cache.map!(&:to_sym)
      @fixed_foreign_keys_cache
    end

    # @return [String] Base class name of the model_class of this InventoryCollection
    def base_class_name
      return "" unless model_class

      @base_class_name ||= model_class.base_class.name
    end

    # @return [String] a concise form of the inventoryCollection for easy logging
    def to_s
      whitelist = ", whitelist: [#{attributes_whitelist.to_a.join(", ")}]" if attributes_whitelist.present?
      blacklist = ", blacklist: [#{attributes_blacklist.to_a.join(", ")}]" if attributes_blacklist.present?

      strategy_name = ", strategy: #{strategy}" if strategy

      name = model_class || association

      "InventoryCollection:<#{name}>#{whitelist}#{blacklist}#{strategy_name}"
    end

    # @return [String] a concise form of the InventoryCollection for easy logging
    def inspect
      to_s
    end

    # @return [Integer] default batch size for talking to the DB
    def batch_size
      # TODO(lsmola) mode to the settings
      1000
    end

    # @return [Integer] default batch size for talking to the DB if not using ApplicationRecord objects
    def batch_size_pure_sql
      # TODO(lsmola) mode to the settings
      10_000
    end

    # Returns a list of stringified uuids of all scoped InventoryObjects, which is used for scoping in targeted mode
    #
    # @return [Array<String>] list of stringified uuids of all scoped InventoryObjects
    def manager_uuids
      # TODO(lsmola) LEGACY: this is still being used by :targetel_arel definitions and it expects array of strings
      raise "This works only for :manager_ref size 1" if manager_ref.size > 1
      key = manager_ref.first
      transform_references_to_hashes(targeted_scope.primary_references).map { |x| x[key] }
    end

    # Builds a multiselection conditions like (table1.a = a1 AND table2.b = b1) OR (table1.a = a2 AND table2.b = b2)
    #
    # @param hashes [Array<Hash>] data we want to use for the query
    # @param keys [Array<Symbol>] keys of attributes involved
    # @return [String] A condition usable in .where of an ActiveRecord relation
    def build_multi_selection_condition(hashes, keys = manager_ref)
      arel_table = model_class.arel_table
      # We do pure SQL OR, since Arel is nesting every .or into another parentheses, otherwise this would be just
      # inject(:or) instead of to_sql with .join(" OR ")
      hashes.map { |hash| "(#{keys.map { |key| arel_table[key].eq(hash[key]) }.inject(:and).to_sql})" }.join(" OR ")
    end

    # @return [ActiveRecord::Relation] A relation that can fetch all data of this InventoryCollection from the DB
    def db_collection_for_comparison
      if targeted?
        if targeted_arel.respond_to?(:call)
          targeted_arel.call(self)
        elsif parent_inventory_collections.present?
          targeted_arel_default
        else
          targeted_iterator_for(targeted_scope.primary_references)
        end
      else
        full_collection_for_comparison
      end
    end

    # Builds targeted query limiting the results by the :references defined in parent_inventory_collections
    #
    # @return [ManagerRefresh::ApplicationRecordIterator] an iterator for default targeted arel
    def targeted_arel_default
      if parent_inventory_collections.collect { |x| x.model_class.base_class }.uniq.count > 1
        raise "Multiple :parent_inventory_collections with different base class are not supported by default. Write "\
              ":targeted_arel manually, or separate [#{self}] into 2 InventoryCollection objects."
      end
      parent_collection = parent_inventory_collections.first
      references        = parent_inventory_collections.map { |x| x.targeted_scope.primary_references }.reduce({}, :merge!)

      parent_collection.targeted_iterator_for(references, full_collection_for_comparison)
    end

    # Gets targeted references and transforms them into list of hashes
    #
    # @param references [Array, ManagerRefresh::Inventorycollection::TargetedScope] passed references
    # @return [Array<Hash>] References transformed into the array of hashes
    def transform_references_to_hashes(references)
      if references.kind_of?(Array)
        # Sliced ManagerRefresh::Inventorycollection::TargetedScope
        references.map { |x| x.second.full_reference }
      else
        references.values.map(&:full_reference)
      end
    end

    # Builds a multiselection conditions like (table1.a = a1 AND table2.b = b1) OR (table1.a = a2 AND table2.b = b2)
    # for passed references
    #
    # @param references [Hash{String => ManagerRefresh::InventoryCollection::Reference}] passed references
    # @return [String] A condition usable in .where of an ActiveRecord relation
    def targeted_selection_for(references)
      build_multi_selection_condition(transform_references_to_hashes(references))
    end

    # Returns iterator for the passed references and a query
    #
    # @param references [Hash{String => ManagerRefresh::InventoryCollection::Reference}] Passed references
    # @param query [ActiveRecord::Relation] relation that can fetch all data of this InventoryCollection from the DB
    # @return [ManagerRefresh::ApplicationRecordIterator] Iterator for the references and query
    def targeted_iterator_for(references, query = nil)
      ManagerRefresh::ApplicationRecordIterator.new(
        :inventory_collection => self,
        :manager_uuids_set    => references,
        :query                => query
      )
    end

    # Builds an ActiveRecord::Relation that can fetch all the references from the DB
    #
    # @param references [Hash{String => ManagerRefresh::InventoryCollection::Reference}] passed references
    # @return [ActiveRecord::Relation] relation that can fetch all the references from the DB
    def db_collection_for_comparison_for(references)
      full_collection_for_comparison.where(targeted_selection_for(references))
    end

    # Builds an ActiveRecord::Relation that can fetch complement of all the references from the DB
    #
    # @param manager_uuids_set [Array<String>] passed references
    # @return [ActiveRecord::Relation] relation that can fetch complement of all the references from the DB
    def db_collection_for_comparison_for_complement_of(manager_uuids_set)
      # TODO(lsmola) this should have the build_multi_selection_condition, like in the method above
      # TODO(lsmola) this query will be highly ineffective, we will try approach with updating a timestamp of all
      # records, then we can get list of all records that were not update. That would be equivalent to result of this
      # more effective query and without need of all manager_uuids
      full_collection_for_comparison.where.not(manager_ref.first => manager_uuids_set)
    end

    # @return [ActiveRecord::Relation] relation that can fetch all the references from the DB
    def full_collection_for_comparison
      return arel unless arel.nil?
      parent.send(association)
    end

    # Creates ManagerRefresh::InventoryObject object from passed hash data
    #
    # @param hash [Hash] Object data
    # @return [ManagerRefresh::InventoryObject] Instantiated ManagerRefresh::InventoryObject
    def new_inventory_object(hash)
      manager_ref.each do |x|
        # TODO(lsmola) with some effort, we can do this, but it's complex
        raise "A lazy_find with a :key can't be a part of the manager_uuid" if inventory_object_lazy?(hash[x]) && hash[x].key
      end

      inventory_object_class.new(self, hash)
    end

    attr_writer :attributes_blacklist, :attributes_whitelist

    private

    # Creates dynamically a subclass of ManagerRefresh::InventoryObject, that will be used per InventoryCollection
    # object. This approach is needed because we want different InventoryObject's getters&setters for each
    # InventoryCollection.
    #
    # @return [ManagerRefresh::InventoryObject] new isolated subclass of ManagerRefresh::InventoryObject
    def inventory_object_class
      @inventory_object_class ||= begin
        klass = Class.new(::ManagerRefresh::InventoryObject)
        klass.add_attributes(inventory_object_attributes) if inventory_object_attributes
        klass
      end
    end

    # Returns array of records identities
    #
    # @param records [Array<ApplicationRecord>, Array[Hash]] list of stored records
    # @return [Array<Hash>] array of records identities
    def records_identities(records)
      records = [records] unless records.respond_to?(:map)
      records.map { |record| record_identity(record) }
    end

    # Returns a hash with a simple record identity
    #
    # @param record [ApplicationRecord, Hash] list of stored records
    # @return [Hash{Symbol => Bigint}] record identity
    def record_identity(record)
      identity = record.try(:[], :id) || record.try(:[], "id") || record.try(:id)
      raise "Cannot obtain identity of the #{record}" if identity.blank?
      {
        :id => identity
      }
    end

    # @return [Array<Symbol>] all association attributes and foreign keys of the model class
    def association_attributes
      model_class.reflect_on_all_associations.map { |x| [x.name, x.foreign_key] }.flatten.compact.map(&:to_sym)
    end
  end
end
