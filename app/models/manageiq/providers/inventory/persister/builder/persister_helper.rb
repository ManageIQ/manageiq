module ManageIQ::Providers::Inventory::Persister::Builder::PersisterHelper
  extend ActiveSupport::Concern

  def add_collection(builder_class, collection_name, extra_properties = {}, settings = {}, &block)
    super(collection_name, builder_class, extra_properties, settings, &block)
  end

  # builder_class for add_collection()
  def cloud
    ::ManageIQ::Providers::Inventory::Persister::Builder::CloudManager
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

  def container
    ::ManageIQ::Providers::Inventory::Persister::Builder::ContainerManager
  end

  # @param extra_settings [Hash]
  def builder_settings(_extra_settings = {})
    opts = super
    opts[:adv_settings] = options.try(:[], :inventory_collections).try(:to_hash) || {}

    opts
  end

  # Returns list of target's ems_refs
  # @return [Array<String>]
  def references(collection)
    target.try(:references, collection) || []
  end

  # Returns list of target's name
  # @return [Array<String>]
  def name_references(collection)
    target.try(:name_references, collection) || []
  end
end
