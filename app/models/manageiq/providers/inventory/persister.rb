class ManageIQ::Providers::Inventory::Persister
  require 'json'
  require 'yaml'
  require_nested :Builder

  attr_reader :manager, :target, :collections

  include ::ManageIQ::Providers::Inventory::Persister::Builder::PersisterHelper

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
  # @return [ManageIQ::Providers::Inventory::Persister] Persister object loaded from a passed JSON
  def self.from_json(json_data)
    from_hash(JSON.parse(json_data))
  end

  # Returns serialized Persisted object to JSON
  # @return [String] serialized Persisted object to JSON
  def to_json
    JSON.dump(to_hash)
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

  # @return [Hash] entire Persister object serialized to hash
  def to_hash
    collections_data = collections.map do |_, collection|
      next if collection.data.blank? &&
              collection.targeted_scope.primary_references.blank? &&
              collection.all_manager_uuids.nil? &&
              collection.skeletal_primary_index.index_data.blank?

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
    # @return [ManageIQ::Providers::Inventory::Persister] Persister object built from serialized data
    def from_hash(persister_data)
      # Extract the specific Persister class
      persister_class = persister_data['class'].constantize
      unless persister_class < ManageIQ::Providers::Inventory::Persister
        raise "Persister class must inherit from a ManageIQ::Providers::Inventory::Persister"
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
