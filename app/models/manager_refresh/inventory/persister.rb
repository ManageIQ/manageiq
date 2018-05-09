class ManagerRefresh::Inventory::Persister
  require 'json'
  require 'yaml'

  attr_reader :manager, :target, :collections

  # @param manager [ManageIQ::Providers::BaseManager] A manager object
  # @param target [Object] A refresh Target object
  def initialize(manager, target = nil)
    @manager = manager
    @target  = target

    @collections = {}

    # call every collection method at least once in order to be initialized
    # otherwise, if the method was not called during parsing it will not be set
    self.class.supported_collections.each do |name|
      public_send(name)
    end

    initialize_inventory_collections
  end

  # Persists InventoryCollection objects into the DB
  def persist!
    ManagerRefresh::SaveInventory.save_inventory(manager, inventory_collections)
  end

  # @return [Array<Symbol>] array of InventoryCollection object names
  def self.supported_collections
    @supported_collections ||= Concurrent::Array.new
  end

  # Returns Persister object loaded from a passed JSON
  #
  # @param json_data [String] input JSON data
  # @return [ManagerRefresh::Inventory::Persister] Persister object loaded from a passed JSON
  def self.from_json(json_data)
    from_hash(JSON.parse(json_data))
  end

  # Returns serialized Persisted object to JSON
  # @return [String] serialized Persisted object to JSON
  def to_json
    JSON.dump(to_hash)
  end

  # Creates method on class that lazy initializes an InventoryCollection
  #
  # @param options [Hash] kwargs for ManagerRefresh::InventoryCollection instantiation
  def self.has_inventory(options)
    name = (options[:association] || options[:model_class].name.pluralize.underscore).to_sym

    supported_collections << name

    define_method(name) do
      collections[name] ||= begin
        collection_options = options.dup

        collection_options[:parent] = manager unless collection_options.key?(:parent)
        collection_options[:parent] = @target if collection_options[:parent] == :target

        if collection_options[:builder_params]
          collection_options[:builder_params] = collection_options[:builder_params].transform_values do |value|
            if value.respond_to?(:call)
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

  # @return [Config::Options] Options for the manager type
  def options
    @options ||= Settings.ems_refresh[manager.class.ems_type]
  end

  # @return [Array<ManagerRefresh::InventoryCollection>] array of InventoryCollection objects of the persister
  def inventory_collections
    collections.values
  end

  # @return [Array<Symbol>] array of InventoryCollection object names of the persister
  def inventory_collections_names
    collections.keys
  end

  # @return [ManagerRefresh::InventoryCollection] returns a defined InventoryCollection or undefined method
  def method_missing(method_name, *arguments, &block)
    if inventory_collections_names.include?(method_name)
      self.class.define_collections_reader(method_name)
      send(method_name)
    else
      super
    end
  end

  # @return [Boolean] true if InventoryCollection with passed method_name name is defined
  def respond_to_missing?(method_name, _include_private = false)
    inventory_collections_names.include?(method_name) || super
  end

  # Defines a new attr reader returning InventoryCollection object
  def self.define_collections_reader(collection_key)
    define_method(collection_key) do
      collections[collection_key]
    end
  end

  protected

  def initialize_inventory_collections
    # can be implemented in a subclass
  end

  # @return [Hash] kwargs shared for all InventoryCollection objects
  def shared_options
    # can be implemented in a subclass
    {}
  end

  # Adds 1 ManagerRefresh::InventoryCollection under a target.collections using :association key as index
  #
  # @param options [Hash] Hash used for ManagerRefresh::InventoryCollection initialize
  def add_inventory_collection(options)
    options[:parent] = manager if !options.key?(:parent) && manager

    if options[:builder_params]
      options[:builder_params] = options[:builder_params].transform_values do |value|
        if value.respond_to?(:call)
          value.call(self)
        else
          value
        end
      end
    end

    collections[options[:association]] = ::ManagerRefresh::InventoryCollection.new(options)
  end

  # Adds multiple inventory collections with the same data
  #
  # @param default [ManagerRefresh::InventoryCollectionDefault] Default
  # @param inventory_collections [Array] Array of method names for passed default parameter
  # @param options [Hash] Hash used for ManagerRefresh::InventoryCollection initialize
  def add_inventory_collections(default, inventory_collections, options = {})
    inventory_collections.each do |inventory_collection|
      add_inventory_collection(shared_options.merge(default.send(inventory_collection, options)))
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

  # @return [Hash] entire Persister object serialized to hash
  def to_hash
    collections_data = collections.map do |_, collection|
      next if collection.data.blank? && collection.targeted_scope.blank? && collection.all_manager_uuids.nil?

      collection.to_hash
    end.compact

    {
      :ems_id      => manager.id,
      :class       => self.class.name,
      :collections => collections_data
    }
  end

  class << self
    protected

    # Returns Persister object built from serialized data
    #
    # @param persister_data [Hash] serialized Persister object in hash
    # @return [ManagerRefresh::Inventory::Persister] Persister object built from serialized data
    def from_hash(persister_data)
      # Extract the specific Persister class
      persister_class = persister_data['class'].constantize
      unless persister_class < ManagerRefresh::Inventory::Persister
        raise "Persister class must inherit from a ManagerRefresh::Inventory::Persister"
      end

      ems = ManageIQ::Providers::BaseManager.find(persister_data['ems_id'])
      persister = persister_class.new(
        ems,
        ManagerRefresh::TargetCollection.new(:manager => ems) # TODO(lsmola) we need to pass serialized targeted scope here
      )

      persister_data['collections'].each do |collection|
        inventory_collection = persister.collections[collection['name'].try(:to_sym)]
        raise "Unrecognized InventoryCollection name: #{inventory_collection}" if inventory_collection.blank?

        inventory_collection.from_hash(collection, persister.collections)
      end
      persister
    end
  end
end
