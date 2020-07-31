class TestPersister < ManageIQ::Providers::Inventory::Persister
  def initialize_inventory_collections
    ######### Cloud ##########
    # Top level models with direct references for Cloud
    %i(vms
       miq_templates).each do |name|

      add_collection(cloud, name) do |builder|
        builder.add_properties(
          :secondary_refs => {:by_name => [:name], :by_uid_ems_and_name => %i(uid_ems name)}
        )
      end
    end

    add_auth_key_pairs

    # Child models with references in the Parent InventoryCollections for Cloud
    %i(availability_zones
       hardwares
       networks
       disks
       vm_and_template_labels
       orchestration_stacks
       orchestration_templates
       orchestration_stacks_outputs
       orchestration_stacks_parameters).each do |name|

      add_collection(cloud, name)
    end

    add_orchestration_stacks_resources

    ######### Network ################
    # Top level models with direct references for Network
    %i(cloud_networks
       cloud_subnets
       security_groups
       load_balancers).each do |name|

      add_collection(network, name) do |builder|
        builder.add_properties(:parent => manager.network_manager)
      end
    end

    add_network_ports

    add_floating_ips

    # Child models with references in the Parent InventoryCollections for Network
    %i(firewall_rules
       cloud_subnet_network_ports
       load_balancer_pools
       load_balancer_pool_members
       load_balancer_pool_member_pools
       load_balancer_listeners
       load_balancer_listener_pools
       load_balancer_health_checks
       load_balancer_health_check_members).each do |name|

      add_collection(network, name) do |builder|
        builder.add_properties(:parent => manager.network_manager)
      end
    end

    # Model we take just from a DB, there is no flavors API
    add_flavors

    ######## Custom processing of Ancestry ##########
    %i(vm_and_miq_template_ancestry
       orchestration_stack_ancestry).each do |name|

      add_collection(cloud, name, {}, {:without_model_class => true})
    end
  end

  private

  # Cloud InventoryCollection
  def add_auth_key_pairs
    add_collection(cloud, :auth_key_pairs) do |builder|
      builder.add_properties(:model_class => ::ManageIQ::Providers::CloudManager::AuthKeyPair)
      builder.add_properties(:manager_uuids => name_references(:key_pairs))
    end
  end

  # Cloud InventoryCollection
  def add_orchestration_stacks_resources
    add_collection(cloud, :orchestration_stacks_resources) do |builder|
      builder.add_properties(:secondary_refs => {:by_stack_and_ems_ref => %i(stack ems_ref)})
    end
  end

  # Cloud InventoryCollection
  def add_flavors
    add_collection(cloud, :flavors) do |builder|
      builder.add_properties(:strategy => :local_db_find_references)
    end
  end

  # Network InventoryCollection
  def add_network_ports
    add_collection(network, :network_ports) do |builder|
      builder.add_properties(
        :manager_uuids  => references(:vms) + references(:network_ports) + references(:load_balancers),
        :parent         => manager.network_manager,
        :secondary_refs => {:by_device => [:device], :by_device_and_name => %i(device name)}
      )
    end
  end

  # Network InventoryCollection
  def add_floating_ips
    add_collection(network, :floating_ips) do |builder|
      builder.add_properties(
        :manager_uuids => references(:floating_ips) + references(:load_balancers),
        :parent        => manager.network_manager
      )
    end
  end

  def options
    {}
  end

  def targeted?
    true
  end

  def strategy
    :local_db_find_missing_references
  end
end
