class ManageIQ::Providers::AnsibleTower::Inventory::Parser::AutomationManager < ManagerRefresh::Inventory::Parser
  def parse
    inventory_groups
    configured_systems
    configuration_scripts
    configuration_script_sources
    credentials
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

      o[:authentications] = []
      %w(credential_id cloud_credential_id network_credential_id).each do |credential_attr|
        next unless i.respond_to?(credential_attr)
        credential_id = i.public_send(credential_attr).to_s
        next if credential_id.blank?
        o[:authentications] << target.credentials.lazy_find(credential_id)
      end
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
        p[:configuration_script_source] = o
        p[:name] = playbook_name
      end
    end
  end

  def credentials
    collector.credentials.each do |i|
      o = target.credentials.find_or_build(i.id.to_s)
      o[:name] = i.name
      # i.description
      # i.host
      o[:userid] = i.username
      # i.password
      # i.security_token
      # i.project
      # i.domain
      # i.ssh_key_data
      # i.ssh_key_unlock
      # i.organization
      # i.become_method # '', 'sudo', 'su', 'pbrun', 'pfexec'
      # i.become_username
      # i.become_password
      # i.vault_password
      # i.subscription
      # i.tenant
      # i.secret
      # i.client
      # i.authorize
      # i.authorize_password
      o[:type] = case i.kind
                   # FIXME: not a big fan of modelling all credentials via inheritance
                 when 'net' then 'ManageIQ::Providers::AnsibleTower::AutomationManager::NetworkCredential'
                 when 'ssh' then 'ManageIQ::Providers::AnsibleTower::AutomationManager::MachineCredential'
                 when 'vmware' then 'ManageIQ::Providers::AnsibleTower::AutomationManager::VmwareCredential'
                   # when 'scm' then 'ManageIQ::Providers::AnsibleTower::AutomationManager::???Credential'
                 when 'aws' then 'ManageIQ::Providers::AnsibleTower::AutomationManager::AmazonCredential'
                 when 'rax' then 'ManageIQ::Providers::AnsibleTower::AutomationManager::RackspaceCredential'
                 when 'satellite6' then 'ManageIQ::Providers::AnsibleTower::AutomationManager::Satellite6Credential'
                   # when 'cloudforms' then 'ManageIQ::Providers::AnsibleTower::AutomationManager::$$$Credential'
                 when 'gce' then 'ManageIQ::Providers::AnsibleTower::AutomationManager::GoogleCredential'
                 when 'azure' then 'ManageIQ::Providers::AnsibleTower::AutomationManager::AzureCredential'
                   # when 'azure_rm' then 'ManageIQ::Providers::AnsibleTower::AutomationManager::???Credential'
                 when 'openstack' then 'ManageIQ::Providers::AnsibleTower::AutomationManager::OpenstackCredential'
                 else 'ManageIQ::Providers::AutomationManager::Authentication'
                 end
    end
  end
end
