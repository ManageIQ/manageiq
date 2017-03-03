class ManagerRefresh::Inventory::Persister
  attr_reader :manager, :target, :collections

  # @param manager [ManageIQ::Providers::BaseManager] A manager object
  # @param target [Object] A refresh Target object
  def initialize(manager, target)
    @manager = manager
    @target  = target

    @collections = {}

    initialize_inventory_collections
  end

  # creates method on class that lazy initializes an InventoryCollection
  def self.has_inventory(options)
    name = options[:association] || options[:model_class].name.pluralize.underscore

    define_method(name) do
      collections[name] ||= begin
        collection_options = options.dup

        unless collection_options[:strategy] == :local_db_find_references
          collection_options[:parent] ||= manager
        end

        if collection_options[:builder_params]
          collection_options[:builder_params] = collection_options[:builder_params].transform_values do |value|
            if value.respond_to? :call
              value.call(self)
            else
              value
            end
          end
        end
        ::ManagerRefresh::InventoryCollection.new(collection_options)
      end
    end
  end

  def options
    @options ||= Settings.ems_refresh[manager.class.ems_type]
  end

  def inventory_collections
    collections.values
  end

  def inventory_collections_names
    collections.keys
  end

  def method_missing(method_name, *arguments, &block)
    if inventory_collections_names.include?(method_name)
      self.class.define_collections_reader(method_name)
      send(method_name)
    else
      super
    end
  end

  def respond_to_missing?(method_name, _include_private = false)
    inventory_collections_names.include?(method_name) || super
  end

  def self.define_collections_reader(collection_key)
    define_method(collection_key) do
      collections[collection_key]
    end
  end

  protected

  def initialize_inventory_collections
    # can be implemented in a subclass
  end

  # Adds 1 ManagerRefresh::InventoryCollection under a target.collections using :association key as index
  #
  # @param options [Hash] Hash used for ManagerRefresh::InventoryCollection initialize
  def add_inventory_collection(options)
    options[:parent] = manager if !options.key?(:parent) && manager

    collections[options[:association]] = ::ManagerRefresh::InventoryCollection.new(options)
  end

  # Adds multiple inventory collections with the same data
  #
  # @param default [ManagerRefresh::InventoryCollectionDefault] Default
  # @param inventory_collections [Array] Array of method names for passed default parameter
  # @param options [Hash] Hash used for ManagerRefresh::InventoryCollection initialize
  def add_inventory_collections(default, inventory_collections, options = {})
    inventory_collections.each do |inventory_collection|
      add_inventory_collection(default.send(inventory_collection, options))
    end
  end

  # Adds remaining inventory collections with the same data
  #
  # @param defaults [Array] Array of ManagerRefresh::InventoryCollectionDefault
  # @param options [Hash] Hash used for ManagerRefresh::InventoryCollection initialize
  def add_remaining_inventory_collections(defaults, options = {})
    defaults.each do |default|
      # Get names of all inventory collections defined in passed classes with Defaults
      all_inventory_collections     = default.methods - ::ManagerRefresh::InventoryCollectionDefault.methods
      # Get names of all defined inventory_collections
      defined_inventory_collections = inventory_collections_names

      # Add all missing inventory_collections with defined init_data
      add_inventory_collections(default,
                                all_inventory_collections - defined_inventory_collections,
                                options)
    end
  end
end
