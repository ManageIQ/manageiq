class ManagerRefresh::Inventory::Target
  attr_reader :collector, :collections

  delegate :manager, :target, :to => :collector

  # @param collector [ManagerRefresh::Inventory::Collector] A collector object
  def initialize(collector)
    @collector   = collector
    @collections = {}
    initialize_inventory_collections
  end

  def inventory_collections
    collections.values
  end

  def inventory_collections_names
    collections.keys
  end

  protected

  def initialize_inventory_collections
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  # Adds 1 ManagerRefresh::InventoryCollection under a target.collections using :association key as index
  #
  # @param inventory_collection_data [Hash] Hash used for ManagerRefresh::InventoryCollection initialize
  def add_inventory_collection(inventory_collection_data)
    data          = inventory_collection_data
    data[:parent] ||= manager

    if !data.key?(:delete_method) && data[:model_class]
      # Automatically infer what the delete method should be, unless the delete methods was given
      data[:delete_method] = data[:model_class].new.respond_to?(:disconnect_inv) ? :disconnect_inv : nil
    end

    collections[data[:association]] = ::ManagerRefresh::InventoryCollection.new(data)
  end

  # Adds multiple inventory collections with the same data
  #
  # @param default [ManagerRefresh::InventoryCollectionDefault] Default
  # @param inventory_collections [Array] Array of method names for passed default parameter
  # @param inventory_collections_data [Hash] Hash used for ManagerRefresh::InventoryCollection initialize
  def add_inventory_collections(default, inventory_collections, inventory_collections_data = {})
    inventory_collections.each do |inventory_collection|
      add_inventory_collection(default.send(inventory_collection, inventory_collections_data))
    end
  end

  # Adds remaining inventory collections with the same data
  #
  # @param defaults [Array] Array of ManagerRefresh::InventoryCollectionDefault
  # @param inventory_collections_data [Hash] Hash used for ManagerRefresh::InventoryCollection initialize
  def add_remaining_inventory_collections(defaults, inventory_collections_data = {})
    defaults.each do |default|
      # Get names of all inventory collections defined in passed classes with Defaults
      all_inventory_collections     = default.methods - ::ManagerRefresh::InventoryCollectionDefault.methods
      # Get names of all defined inventory_collections
      defined_inventory_collections = inventory_collections_names

      # Add all missing inventory_collections with defined init_data
      add_inventory_collections(default,
                                all_inventory_collections - defined_inventory_collections,
                                inventory_collections_data)
    end
  end
end
