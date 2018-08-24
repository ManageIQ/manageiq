module InitDataHelper
  def initialize_all_inventory_collections
    # Initialize the InventoryCollections
    @data = {}
    all_collections.each do |collection|
      @data[collection] = ::ManagerRefresh::InventoryCollection.new(send("#{collection}_init_data"))
    end
  end

  def initialize_inventory_collections(only_collections)
    # Initialize the InventoryCollections
    @data = {}
    only_collections.each do |collection|
      @data[collection] = ::ManagerRefresh::InventoryCollection.new(send("#{collection}_init_data",
                                                                         :complete => false))
    end

    (all_collections - only_collections).each do |collection|
      @data[collection] = ::ManagerRefresh::InventoryCollection.new(send("#{collection}_init_data",
                                                                         :complete => false,
                                                                         :strategy => :local_db_cache_all))
    end
  end

  def orchestration_stacks_init_data(extra_attributes = {})
    # Shadowing the default blacklist so we have an automatically solved graph cycle
    data = cloud.prepare_data(:orchestration_stacks, persister_class) do |builder|
      builder.add_properties(:model_class => ::ManageIQ::Providers::CloudManager::OrchestrationStack)
    end.to_hash

    init_data(data.merge(extra_attributes.merge(:attributes_blacklist => [])))
  end

  def orchestration_stacks_resources_init_data(extra_attributes = {})
    # Shadowing the default blacklist so we have an automatically solved graph cycle
    data = cloud.prepare_data(:orchestration_stacks_resources, persister_class).to_hash
    init_data(data.merge(extra_attributes))
  end

  def vms_init_data(extra_attributes = {})
    data = cloud.prepare_data(:vms, persister_class).to_hash
    init_data(data.merge(extra_attributes.merge(:attributes_blacklist => [])))
  end

  def miq_templates_init_data(extra_attributes = {})
    data = cloud.prepare_data(:miq_templates, persister_class).to_hash
    init_data(data.merge(extra_attributes))
  end

  def key_pairs_init_data(extra_attributes = {})
    data = cloud.prepare_data(:key_pairs, persister_class).to_hash
    init_data(data.merge(extra_attributes))
  end

  def hardwares_init_data(extra_attributes = {})
    data = cloud.prepare_data(:hardwares, persister_class).to_hash
    init_data(data.merge(extra_attributes))
  end

  def disks_init_data(extra_attributes = {})
    data = cloud.prepare_data(:disks, persister_class).to_hash
    init_data(data.merge(extra_attributes))
  end

  def network_ports_init_data(extra_attributes = {})
    data = network.prepare_data(:network_ports, persister_class).to_hash
    init_data(data.merge(extra_attributes))
  end

  # Following 2 are fictional, not like this in practice.
  def container_quota_items_init_data(extra_attributes = {})
    init_data(extra_attributes).merge(
      :model_class => ContainerQuotaItem,
      :arel        => ContainerQuotaItem.all,
      :manager_ref => [:quota_desired], # a decimal column
    )
  end

  # Quota items don't even have custom attrs; this is just to have a dependent
  # for quota items collection to test their .id are set correctly.
  def container_quota_items_attrs_init_data(extra_attributes = {})
    init_data(extra_attributes).merge(
      :model_class => CustomAttribute,
      :arel        => CustomAttribute.where(:resource_type => 'ContainerQuotaItem'),
      :manager_ref => [:name],
    )
  end

  def cloud
    ManageIQ::Providers::Inventory::Persister::Builder::CloudManager
  end

  def network
    ManageIQ::Providers::Inventory::Persister::Builder::NetworkManager
  end

  def persister_class
    ManageIQ::Providers::Inventory::Persister
  end

  def init_data(extra_attributes)
    init_data = {
      :parent => @ems,
    }

    init_data.merge!(extra_attributes)
  end

  def association_attributes(model_class)
    # All association attributes and foreign keys of the model
    model_class.reflect_on_all_associations.map { |x| [x.name, x.foreign_key] }.flatten.compact.map(&:to_sym)
  end

  def custom_association_attributes
    # These are associations that are not modeled in a standard rails way, e.g. the ancestry
    [:parent, :genealogy_parent, :genealogy_parent_object]
  end
end
