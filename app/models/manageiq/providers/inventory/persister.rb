class ManageIQ::Providers::Inventory::Persister
  require 'json'
  require 'yaml'

  attr_reader :manager, :target, :collections, :tag_mapper

  include ::ManageIQ::Providers::Inventory::Persister::Builder::PersisterHelper
  include Vmdb::Logging

  # @param manager [ManageIQ::Providers::BaseManager] A manager object
  # @param target [Object] A refresh Target object
  def initialize(manager, target = nil)
    @manager = manager
    @target  = target

    @collections = {}

    initialize_inventory_collections
  end

  # Persists InventoryCollection objects into the DB
  def persist!
    InventoryRefresh::SaveInventory.save_inventory(manager, inventory_collections)
    publish_inventory(manager, target)
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

  # @return [Array<InventoryRefresh::InventoryCollection>] array of InventoryCollection objects of the persister
  def inventory_collections
    collections.values
  end

  # @return [Array<Symbol>] array of InventoryCollection object names of the persister
  def inventory_collections_names
    collections.keys
  end

  # Defines how inventory objects will be loaded from the database
  #
  # Allowed values are:
  # * nil - Default strategy, InventoryObjects will be saved and only objects in
  #         an InventoryCollection can be referenced.  Best used for full refreshes.
  # * :local_db_find_missing_references - InventoryObjects will be saved and
  #         lazy_find references will be loaded from the database.  Best used
  #         for targeted refreshes.
  def strategy
    targeted? ? :local_db_find_missing_references : nil
  end

  def saver_strategy
    :default
  end

  # Persisters for targeted refresh can override to true
  def targeted?
    false
  end

  def parent
    manager.presence
  end

  def cloud_manager
    manager.kind_of?(EmsCloud) ? manager : manager.parent_manager
  end

  def network_manager
    manager.kind_of?(EmsNetwork) ? manager : manager.network_manager
  end

  def storage_manager
    manager.kind_of?(EmsStorage) ? manager : manager.storage_manager
  end

  def assert_graph_integrity?
    !Rails.env.production?
  end

  # @return [InventoryRefresh::InventoryCollection] returns a defined InventoryCollection or undefined method
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

  def self.provider_module
    ManageIQ::Providers::Inflector.provider_module(self).name
  end

  def publish_inventory(ems, target)
    return unless publish_inventory?

    ems_identifier = "#{ems.emstype}__#{ems.id}"

    messaging_client = MiqQueue.messaging_client(ems_identifier)
    return if messaging_client.nil?

    collections.each_value do |collection|
      inventory_objects = collection.to_hash[:data].to_a

      payloads = inventory_objects.map do |inventory_object_hash|
        reference         = inventory_object_hash.values_at(*collection.manager_ref).join("__")
        target_identifier = "#{ems_identifier}__#{collection.name}__#{reference}"

        {
          :service => "manageiq.ems-inventory",
          :sender  => ems_identifier,
          :event   => target_identifier,
          :payload => {
            :ems_id         => ems.id,
            :ems_identifier => ems_identifier,
            :collection     => collection.name,
            :data           => inventory_object_hash
          }
        }
      end

      messaging_client.publish_topic(payloads) if payloads.present?
    end
  rescue => err
    _log.warn("Failed to publish inventory for target #{target.class} [#{target.name}] id [#{target.id}]: #{err}")
  end

  private

  def publish_inventory?
    Settings.ems_refresh.syndicate_inventory && MiqQueue.messaging_type != "miq_queue"
  end

  protected

  def initialize_inventory_collections
    # can be implemented in a subclass
  end

  def case_sensitive_labels?
    true
  end

  def initialize_tag_mapper
    @tag_mapper ||= ProviderTagMapping.mapper(:case_sensitive_labels => case_sensitive_labels?)
    collections[:tags_to_resolve] = @tag_mapper.tags_to_resolve_collection
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
        InventoryRefresh::TargetCollection.new(:manager => ems) # TODO(lsmola) we need to pass serialized targeted scope here
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
