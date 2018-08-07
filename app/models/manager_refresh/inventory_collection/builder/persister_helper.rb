module ManagerRefresh::InventoryCollection::Builder::PersisterHelper
  extend ActiveSupport::Concern

  # Interface for creating InventoryCollection under @collections
  #
  # @param builder_class    [ManagerRefresh::InventoryCollection::Builder] or subclasses
  # @param collection_name  [Symbol || Array] used as InventoryCollection:association
  # @param extra_properties [Hash]   props from InventoryCollection.initialize list
  #         - adds/overwrites properties added by builder
  #
  # @param settings [Hash] builder settings
  #         - @see ManagerRefresh::InventoryCollection::Builder.default_options
  #         - @see make_builder_settings()
  #
  # @example
  #   add_collection(ManagerRefresh::InventoryCollection::Builder::CloudManager, :vms) do |builder|
  #     builder.add_properties(
  #       :strategy => :local_db_cache_all,
  #     )
  #   )
  #
  # @see documentation https://github.com/ManageIQ/guides/tree/master/providers/persister/inventory_collections.md
  #
  def add_collection(builder_class, collection_name, extra_properties = {}, settings = {}, &block)
    builder = builder_class.prepare_data(collection_name,
                                         self.class,
                                         make_builder_settings(settings),
                                         &block)

    builder.add_properties(extra_properties) if extra_properties.present?

    builder.add_properties({:manager_uuids => references(collection_name)}, :if_missing) if targeted?

    builder.evaluate_lambdas!(self)

    collections[collection_name] = builder.to_inventory_collection
  end

  # builder_class for add_collection()
  def cloud
    ::ManagerRefresh::InventoryCollection::Builder::CloudManager
  end

  # builder_class for add_collection()
  def network
    ::ManagerRefresh::InventoryCollection::Builder::NetworkManager
  end

  # builder_class for add_collection()
  def infra
    ::ManagerRefresh::InventoryCollection::Builder::InfraManager
  end

  # builder_class for add_collection()
  def storage
    ::ManagerRefresh::InventoryCollection::Builder::StorageManager
  end

  # builder_class for add_collection()
  def automation
    ::ManagerRefresh::InventoryCollection::Builder::AutomationManager
  end

  # builder class for add_collection()
  def physical_infra
    ::ManagerRefresh::InventoryCollection::Builder::PhysicalInfraManager
  end

  def container
    ::ManagerRefresh::InventoryCollection::Builder::ContainerManager
  end

  # @param extra_settings [Hash]
  #   :auto_inventory_attributes
  #     - auto creates inventory_object_attributes from target model_class setters
  #     - attributes used in InventoryObject.add_attributes
  #   :without_model_class
  #     - if false and no model_class derived or specified, throws exception
  #     - doesn't try to derive model class automatically
  #     - @see method ManagerRefresh::InventoryCollection::Builder.auto_model_class
  def make_builder_settings(extra_settings = {})
    opts = ::ManagerRefresh::InventoryCollection::Builder.default_options

    opts[:adv_settings] = options.try(:[], :inventory_collections).try(:to_hash) || {}
    opts[:shared_properties] = shared_options
    opts[:auto_inventory_attributes] = true
    opts[:without_model_class] = false

    opts.merge(extra_settings)
  end

  def strategy
    nil
  end

  # Persisters for targeted refresh can override to true
  def targeted?
    false
  end

  # @return [Hash] kwargs shared for all InventoryCollection objects
  def shared_options
    {
      :strategy => strategy,
      :targeted => targeted?,
      :parent   => manager.presence
    }
  end

  # Returns list of target's ems_refs
  # @return [Array<String>]
  def references(collection)
    target.try(:manager_refs_by_association).try(:[], collection).try(:[], :ems_ref).try(:to_a) || []
  end

  # Returns list of target's name
  # @return [Array<String>]
  def name_references(collection)
    target.try(:manager_refs_by_association).try(:[], collection).try(:[], :name).try(:to_a) || []
  end
end
