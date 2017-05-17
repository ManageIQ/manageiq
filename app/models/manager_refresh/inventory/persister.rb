class ManagerRefresh::Inventory::Persister
  require 'json'

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

  def self.supported_collections
    @supported_collections ||= Concurrent::Array.new
  end

  def self.from_json(json_data)
    from_raw_data(JSON.parse(json_data))
  end

  def to_json
    JSON.dump(to_raw_data)
  end

  # creates method on class that lazy initializes an InventoryCollection
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

    if options[:builder_params]
      options[:builder_params] = options[:builder_params].transform_values do |value|
        if value.respond_to? :call
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

  def to_raw_data
    collections_data = collections.map do |key, collection|
      next if collection.data.blank?

      {
        :name         => key,
        :unique_uuids => [], # TODO(lsmola) allow to set a scope, so we can say it's a complete set of data
        :data         => collection.to_raw_data
      }
    end.compact

    {
      :ems_id      => manager.id,
      :class       => self.class.name,
      :collections => collections_data
    }
  end

  class << self
    protected

    def from_raw_data(persister_data)
      # Extract the specific Persister class
      persister_class = persister_data['class'].constantize
      unless persister_class < ManagerRefresh::Inventory::Persister
        raise "Persister class must inherit from a ManagerRefresh::Inventory::Persister"
      end

      # TODO(lsmola) do we need a target in this case?
      # Load the Persister object and fill the InventoryCollections with the data
      persister = persister_class.new(ManageIQ::Providers::BaseManager.find(persister_data['ems_id']))
      persister_data['collections'].each do |collection|
        inventory_collection = persister.collections[collection['name'].try(:to_sym)]
        raise "Unrecognized InventoryCollection name: #{inventory_collection}" if inventory_collection.blank?

        inventory_collection.from_raw_data(collection['data'], persister.collections)
      end
      persister
    end
  end
end
