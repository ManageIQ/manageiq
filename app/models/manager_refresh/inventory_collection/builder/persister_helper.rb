module ManagerRefresh::InventoryCollection::Builder::PersisterHelper
  extend ActiveSupport::Concern

  # Interface for creating InventoryCollection under @collections
  #
  # @param builder_class    [ManagerRefresh::InventoryCollection::Builder] or subclasses
  # @param collection_name  [Symbol] used as InventoryCollection:association
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
  # @see ManagerRefresh::InventoryCollection::Builder
  #
  def add_collection(builder_class, collection_name, extra_properties = {}, settings = {}, &block)
    builder = builder_class.prepare_data(collection_name,
                                         self.class,
                                         make_builder_settings(settings),
                                         &block)

    builder.add_properties(extra_properties) if extra_properties.present?

    builder.add_properties({:manager_uuids => references(collection_name)}, :if_missing) if targeted?

    builder.add_parent_if_missing(manager, targeted?) if manager.present?

    builder.evaluate_lambdas!(self)

    collections[collection_name] = builder.to_inventory_collection
  end

  def cloud
    ::ManagerRefresh::InventoryCollection::Builder::CloudManager
  end

  def network
    ::ManagerRefresh::InventoryCollection::Builder::NetworkManager
  end

  def infra
    ::ManagerRefresh::InventoryCollection::Builder::InfraManager
  end

  def storage
    ::ManagerRefresh::InventoryCollection::Builder::StorageManager
  end

  def automation
    ::ManagerRefresh::InventoryCollection::Builder::AutomationManager
  end

  # @param extra_settings [Hash]
  def make_builder_settings(extra_settings = {})
    opts = ::ManagerRefresh::InventoryCollection::Builder.default_options

    opts[:adv_settings] = options[:inventory_collections].try(:to_hash) || {}
    opts[:shared_properties] = shared_options

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
    # can be implemented in a subclass
    {}
  end

  # Returns list of target's ems_refs
  # @return [Array<String>]
  def references(collection)
    target.manager_refs_by_association.try(:[], collection).try(:[], :ems_ref).try(:to_a) || []
  end

  # Returns list of target's name
  # @return [Array<String>]
  def name_references(collection)
    target.manager_refs_by_association.try(:[], collection).try(:[], :name).try(:to_a) || []
  end
end
