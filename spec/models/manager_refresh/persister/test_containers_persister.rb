class TestContainersPersister < ManagerRefresh::Inventory::Persister
  include ManageIQ::Providers::Kubernetes::Inventory::Persister::Definitions::ContainerCollections

  def initialize_inventory_collections
    super

    initialize_container_inventory_collections

    # get_container_images=false mode is a stopgap to speed up refresh by reducing functionality.
    # Skipping these InventoryCollections (instead of returning empty ones)
    # to at least retain existing metadata if it was true and is now false.
    if options.get_container_images
      add_custom_attributes(:container_images, %w(labels docker_labels))
    end
  end

  protected

  def targeted?
    true
  end

  def strategy
    :local_db_find_references
  end

  def shared_options
    {
      :strategy => strategy,
      :targeted => targeted?,
      :parent   => manager.presence
    }
  end
end
