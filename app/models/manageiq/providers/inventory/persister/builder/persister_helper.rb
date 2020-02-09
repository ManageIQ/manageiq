module ManageIQ::Providers::Inventory::Persister::Builder::PersisterHelper
  extend ActiveSupport::Concern

  # Interface for creating InventoryCollection under @collections
  #
  # @param builder_class    [class<ManageIQ::Providers::Inventory::Persister::Builder>] or subclasses
  # @param collection_name  [Symbol || Array] used as InventoryCollection:association
  # @param extra_properties [Hash]   props from InventoryCollection.initialize list
  #         - adds/overwrites properties added by builder
  #
  # @param settings [Hash] builder settings
  #         - @see ManageIQ::Providers::Inventory::Persister::Builder.default_options
  #         - @see make_builder_settings()
  #
  # @example
  #   add_collection(ManageIQ::Providers::Inventory::Persister::Builder::CloudManager, :vms) do |builder|
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
    ::ManageIQ::Providers::Inventory::Persister::Builder::CloudManager
  end

  def configuration
    ::ManageIQ::Providers::Inventory::Persister::Builder::ConfigurationManager
  end

  # builder_class for add_collection()
  def network
    ::ManageIQ::Providers::Inventory::Persister::Builder::NetworkManager
  end

  # builder_class for add_collection()
  def infra
    ::ManageIQ::Providers::Inventory::Persister::Builder::InfraManager
  end

  # builder_class for add_collection()
  def storage
    ::ManageIQ::Providers::Inventory::Persister::Builder::StorageManager
  end

  # builder_class for add_collection()
  def automation
    ::ManageIQ::Providers::Inventory::Persister::Builder::AutomationManager
  end

  # builder class for add_collection()
  def physical_infra
    ::ManageIQ::Providers::Inventory::Persister::Builder::PhysicalInfraManager
  end

  def provisioning
    ::ManageIQ::Providers::Inventory::Persister::Builder::ProvisioningManager
  end

  def container
    ::ManageIQ::Providers::Inventory::Persister::Builder::ContainerManager
  end

  # @param extra_settings [Hash]
  #   :auto_inventory_attributes
  #     - auto creates inventory_object_attributes from target model_class setters
  #     - attributes used in InventoryObject.add_attributes
  #   :without_model_class
  #     - if false and no model_class derived or specified, throws exception
  #     - doesn't try to derive model class automatically
  #     - @see method ManageIQ::Providers::Inventory::Persister::Builder.auto_model_class
  def make_builder_settings(extra_settings = {})
    opts = ::ManageIQ::Providers::Inventory::Persister::Builder.default_options

    opts[:adv_settings] = options.try(:[], :inventory_collections).try(:to_hash) || {}
    opts[:shared_properties] = shared_options
    opts[:auto_inventory_attributes] = true
    opts[:without_model_class] = false

    opts.merge(extra_settings)
  end

  # @return [Hash] kwargs shared for all InventoryCollection objects
  def shared_options
    {
      :strategy               => strategy,
      :saver_strategy         => saver_strategy,
      :targeted               => targeted?,
      :parent                 => parent,
      :assert_graph_integrity => assert_graph_integrity?,
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
