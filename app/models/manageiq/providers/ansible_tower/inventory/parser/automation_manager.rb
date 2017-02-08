class ManageIQ::Providers::AnsibleTower::Inventory::Parser::AutomationManager < ManagerRefresh::Inventory::Parser
  def parse
    inventory_groups
    configured_systems
    configuration_scripts
    configuration_script_sources
  end

  def inventory_groups
    collector.inventories.each do |i|
      o = target.inventory_groups.find_or_build(i.id.to_s)
      o[:name] = i.name
    end
  end

  def configured_systems
    collector.hosts.each do |i|
      o = target.configured_systems.find_or_build(i.id)
      o[:hostname] = i.name
      o[:virtual_instance_ref] = i.instance_id
      o[:inventory_root_group] = target.inventory_groups.lazy_find(i.inventory_id.to_s)
      o[:counterpart] = Vm.find_by(:uid_ems => i.instance_id)
    end
  end

  def configuration_scripts
    collector.job_templates.each do |i|
      o = target.configuration_scripts.find_or_build(i.id.to_s)
      o[:description] = i.description
      o[:name] = i.name
      o[:survey_spec] = i.survey_spec_hash
      o[:variables] = i.extra_vars_hash
      o[:inventory_root_group] = target.inventory_groups.lazy_find(i.inventory_id.to_s)
    end
  end

  def configuration_script_sources
    collector.projects.each do |i|
      o = target.configuration_script_sources.find_or_build(i.id.to_s)
      o[:description] = i.description
      o[:name] = i.name

      i.playbooks.each do |playbook_name|
        # FIXME: its not really nice how I have to build a manager_ref / uuid here
        p = target.playbooks.find_or_build("#{i.id}__#{playbook_name}")
        # FIXME: how about just adding `o` - configuration_script_source here?
        p[:configuration_script_source] = target.configuration_script_sources.lazy_find(i.id.to_s)
        p[:name] = playbook_name
      end
    end
  end
end
