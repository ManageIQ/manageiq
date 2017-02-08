class ManageIQ::Providers::AnsibleTower::AutomationManager::RefreshWorker::Parser
  attr_reader :inventory, :ems

  def initialize(ems, target, inventory)
    @ems    = ems
    @target = target
    @inventory = inventory
  end

  def parse
    parse_configuration_script_sources

    [
      inventory_groups,
      configured_systems,
      configuration_scripts,
      configuration_script_sources,
      playbooks,
    ]
  end

  def inventory_groups
    @inventory_groups ||= ManagerRefresh::InventoryCollection.new(
      ManageIQ::Providers::AutomationManager::InventoryRootGroup,
      :association => :inventory_root_groups,
      :parent      => ems,
    ).tap do |c|
      inventory.inventories.each do |i|
        c << c.new_inventory_object(
          # to_s should not be necessary, but its needed to resolve lazy find
          :ems_ref => i.id.to_s,
          :manager => ems,
          :name    => i.name,
        )
      end
    end
  end

  def configured_systems
    ManagerRefresh::InventoryCollection.new(
      ManageIQ::Providers::AnsibleTower::AutomationManager::ConfiguredSystem,
      :association => :configured_systems,
      :manager_ref => [:manager_ref],
      :parent      => ems,
    ).tap do |c|
      inventory.hosts.each do |i|
        c << c.new_inventory_object(
          :manager_ref          => i.id,
          :manager              => ems,
          :hostname             => i.name,
          # to_s should not be necessary, but its needed to resolve lazy find
          :inventory_root_group => inventory_groups.lazy_find(i.inventory_id.to_s),
          :virtual_instance_ref => i.instance_id,
          # FIXME: dont access db here
          :counterpart          => Vm.find_by(:uid_ems => i.instance_id)
        )
      end
    end
  end

  def configuration_scripts
    ManagerRefresh::InventoryCollection.new(
      ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript,
      :association => :configuration_scripts,
      :manager_ref => [:manager_ref],
      :parent      => ems,
    ).tap do |c|
      inventory.job_templates.each do |i|
        c << c.new_inventory_object(
          :description          => i.description,
          :inventory_root_group => inventory_groups.lazy_find(i.inventory_id.to_s),
          :manager              => ems,
          :manager_ref          => i.id.to_s,
          :name                 => i.name,
          :survey_spec          => i.survey_spec_hash,
          :variables            => i.extra_vars_hash,
        )
      end
    end
  end

  def configuration_script_sources
    @configuration_script_sources ||= ManagerRefresh::InventoryCollection.new(
      ConfigurationScriptSource,
      :association => :configuration_script_sources,
      :manager_ref => [:manager_ref],
      :parent      => ems,
    )
  end

  def playbooks
    @playbooks ||= ManagerRefresh::InventoryCollection.new(
      ManageIQ::Providers::AnsibleTower::AutomationManager::Playbook,
      :association => :configuration_script_payloads,
      :manager_ref => [:manager_ref],
      :parent      => ems,
    )
  end

  def parse_configuration_script_sources
    inventory.projects.each do |i|
      configuration_script_sources << configuration_script_sources.new_inventory_object(
        :manager     => ems,
        :manager_ref => i.id.to_s,
        :name        => i.name,
        :description => i.description,
      )

      i.playbooks.each do |playbook|
        playbooks << playbooks.new_inventory_object(
          :configuration_script_source => configuration_script_sources.lazy_find(i.id.to_s),
          :name                        => playbook,
          :manager_ref                 => playbook,
        )
      end
    end
  end
end
