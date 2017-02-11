class ManageIQ::Providers::AnsibleTower::Inventory::Parser::AutomationManager < ManagerRefresh::Inventory::Parser
  def parse
    inventory_groups
    configured_systems
    configuration_scripts
    configuration_script_sources
    credentials
  end

  def inventory_groups
    collector.inventories.each do |inventory|
      inventory_object = target.inventory_groups.find_or_build(inventory.id.to_s)
      inventory_object[:name] = inventory.name
    end
  end

  def configured_systems
    collector.hosts.each do |host|
      inventory_object = target.configured_systems.find_or_build(host.id)
      inventory_object[:hostname] = host.name
      inventory_object[:virtual_instance_ref] = host.instance_id
      inventory_object[:inventory_root_group] = target.inventory_groups.lazy_find(host.inventory_id.to_s)
      inventory_object[:counterpart] = Vm.find_by(:uid_ems => host.instance_id)
    end
  end

  def configuration_scripts
    collector.job_templates.each do |job_template|
      inventory_object = target.configuration_scripts.find_or_build(job_template.id.to_s)
      inventory_object[:description] = job_template.description
      inventory_object[:name] = job_template.name
      inventory_object[:survey_spec] = job_template.survey_spec_hash
      inventory_object[:variables] = job_template.extra_vars_hash
      inventory_object[:inventory_root_group] = target.inventory_groups.lazy_find(job_template.inventory_id.to_s)

      inventory_object[:authentications] = []
      %w(credential_id cloud_credential_id network_credential_id).each do |credential_attr|
        next unless job_template.respond_to?(credential_attr)
        credential_id = job_template.public_send(credential_attr).to_s
        next if credential_id.blank?
        inventory_object[:authentications] << target.credentials.lazy_find(credential_id)
      end
    end
  end

  def configuration_script_sources
    collector.projects.each do |project|
      inventory_object = target.configuration_script_sources.find_or_build(project.id.to_s)
      inventory_object[:description] = project.description
      inventory_object[:name] = project.name

      project.playbooks.each do |playbook_name|
        # FIXME: its not really nice how I have to build a manager_ref / uuid here
        inventory_object_playbook = target.playbooks.find_or_build("#{project.id}__#{playbook_name}")
        inventory_object_playbook[:configuration_script_source] = inventory_object
        inventory_object_playbook[:name] = playbook_name
      end
    end
  end

  def credentials
    collector.credentials.each do |credential|
      inventory_object = target.credentials.find_or_build(credential.id.to_s)
      inventory_object[:name] = credential.name
      inventory_object[:userid] = credential.username
      # credential.description
      # credential.host
      # credential.password
      # credential.security_token
      # credential.project
      # credential.domain
      # credential.ssh_key_data
      # credential.ssh_key_unlock
      # credential.organization
      # credential.become_method # '', 'sudo', 'su', 'pbrun', 'pfexec'
      # credential.become_username
      # credential.become_password
      # credential.vault_password
      # credential.subscription
      # credential.tenant
      # credential.secret
      # credential.client
      # credential.authorize
      # credential.authorize_password
      inventory_object[:type] = case credential.kind
                                when 'net' then 'ManageIQ::Providers::AnsibleTower::AutomationManager::NetworkCredential'
                                when 'ssh' then 'ManageIQ::Providers::AnsibleTower::AutomationManager::MachineCredential'
                                when 'vmware' then 'ManageIQ::Providers::AnsibleTower::AutomationManager::VmwareCredential'
                                # when 'scm' then 'ManageIQ::Providers::AnsibleTower::AutomationManager::???Credential'
                                when 'aws' then 'ManageIQ::Providers::AnsibleTower::AutomationManager::AmazonCredential'
                                when 'rax' then 'ManageIQ::Providers::AnsibleTower::AutomationManager::RackspaceCredential'
                                when 'satellite6' then 'ManageIQ::Providers::AnsibleTower::AutomationManager::Satellite6Credential'
                                # when 'cloudforms' then 'ManageIQ::Providers::AnsibleTower::AutomationManager::$$$Credential'
                                when 'gce' then 'ManageIQ::Providers::AnsibleTower::AutomationManager::GoogleCredential'
                                # when 'azure' then 'ManageIQ::Providers::AnsibleTower::AutomationManager::???Credential'
                                when 'azure_rm' then 'ManageIQ::Providers::AnsibleTower::AutomationManager::AzureCredential'
                                when 'openstack' then 'ManageIQ::Providers::AnsibleTower::AutomationManager::OpenstackCredential'
                                else 'ManageIQ::Providers::AutomationManager::Authentication'
                                end
    end
  end
end
