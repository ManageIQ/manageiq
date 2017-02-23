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
    init_data(cloud.orchestration_stacks(extra_attributes.merge(:attributes_blacklist => [])))
  end

  def orchestration_stacks_resources_init_data(extra_attributes = {})
    # Shadowing the default blacklist so we have an automatically solved graph cycle
    init_data(cloud.orchestration_stacks_resources(extra_attributes))
  end

  def vms_init_data(extra_attributes = {})
    init_data(cloud.vms(extra_attributes.merge(:attributes_blacklist => [])))
  end

  def miq_templates_init_data(extra_attributes = {})
    init_data(cloud.miq_templates(extra_attributes))
  end

  def key_pairs_init_data(extra_attributes = {})
    init_data(cloud.key_pairs(extra_attributes))
  end

  def hardwares_init_data(extra_attributes = {})
    init_data(cloud.hardwares(extra_attributes))
  end

  def disks_init_data(extra_attributes = {})
    init_data(cloud.disks(extra_attributes))
  end

  def network_ports_init_data(extra_attributes = {})
    init_data(network.network_ports(extra_attributes))
  end

  def cloud
    ManagerRefresh::InventoryCollectionDefault::CloudManager
  end

  def network
    ManagerRefresh::InventoryCollectionDefault::NetworkManager
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
