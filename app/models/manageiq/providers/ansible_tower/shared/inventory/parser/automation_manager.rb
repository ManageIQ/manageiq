module ManageIQ::Providers::AnsibleTower::Shared::Inventory::Parser::AutomationManager
  def parse
    inventory_root_groups
    configured_systems
    configuration_scripts
    configuration_script_sources
    credentials
  end

  def inventory_root_groups
    collector.inventories.each do |inventory|
      inventory_object = persister.inventory_root_groups.find_or_build(inventory.id.to_s)
      inventory_object.name = inventory.name
    end
  end

  def configured_systems
    collector.hosts.each do |host|
      inventory_object = persister.configured_systems.find_or_build(host.id)
      inventory_object.hostname = host.name
      inventory_object.virtual_instance_ref = host.instance_id
      inventory_object.inventory_root_group = persister.inventory_root_groups.lazy_find(host.inventory_id.to_s)
      inventory_object.counterpart = persister.vms.lazy_find(host.instance_id)
    end
  end

  def configuration_scripts
    collector.job_templates.each do |job_template|
      inventory_object = persister.configuration_scripts.find_or_build(job_template.id.to_s)
      inventory_object.description = job_template.description
      inventory_object.name = job_template.name
      inventory_object.survey_spec = job_template.survey_spec_hash
      inventory_object.variables = job_template.extra_vars_hash
      inventory_object.inventory_root_group = persister.inventory_root_groups.lazy_find(job_template.inventory_id.to_s)
      inventory_object.parent = persister.configuration_script_payloads.lazy_find(
        :configuration_script_source => job_template.project_id,
        :manager_ref                 => job_template.playbook
      )

      inventory_object.authentications = []
      %w(credential_id cloud_credential_id network_credential_id).each do |credential_attr|
        next unless job_template.respond_to?(credential_attr)
        credential_id = job_template.public_send(credential_attr).to_s
        next if credential_id.blank?
        inventory_object.authentications << persister.credentials.lazy_find(credential_id)
      end
    end
  end

  def configuration_script_sources
    collector.projects.each do |project|
      inventory_object = persister.configuration_script_sources.find_or_build(project.id.to_s)
      inventory_object.description = project.description
      inventory_object.name = project.name
      # checking project.credential due to https://github.com/ansible/ansible_tower_client_ruby/issues/68
      inventory_object.authentication = persister.credentials.lazy_find(project.try(:credential_id).to_s)
      inventory_object.scm_type = project.scm_type
      inventory_object.scm_url = project.scm_url
      inventory_object.scm_branch = project.scm_branch
      inventory_object.scm_clean = project.scm_clean
      inventory_object.scm_delete_on_update = project.scm_delete_on_update
      inventory_object.scm_update_on_launch = project.scm_update_on_launch
      inventory_object.status = project.status

      project.playbooks.each do |playbook_name|
        inventory_object_playbook = persister.configuration_script_payloads.find_or_build_by(
          :configuration_script_source => inventory_object,
          :manager_ref                 => playbook_name
        )
        inventory_object_playbook.name = playbook_name
      end
    end
  end

  def credentials
    collector.credentials.each do |credential|
      inventory_object = persister.credentials.find_or_build(credential.id.to_s)
      inventory_object.name = credential.name
      inventory_object.userid = credential.username
      provider_module = ManageIQ::Providers::Inflector.provider_module(collector.manager.class).name
      inventory_object.type = case credential.kind
                                when 'net' then "#{provider_module}::AutomationManager::NetworkCredential"
                                when 'ssh' then "#{provider_module}::AutomationManager::MachineCredential"
                                when 'vmware' then "#{provider_module}::AutomationManager::VmwareCredential"
                                when 'scm' then "#{provider_module}::AutomationManager::ScmCredential"
                                when 'aws' then "#{provider_module}::AutomationManager::AmazonCredential"
                                when 'rax' then "#{provider_module}::AutomationManager::RackspaceCredential"
                                when 'satellite6' then "#{provider_module}::AutomationManager::Satellite6Credential"
                                # when 'cloudforms' then "#{provider_module}::AutomationManager::$$$Credential"
                                when 'gce' then "#{provider_module}::AutomationManager::GoogleCredential"
                                when 'azure' then "#{provider_module}::AutomationManager::AzureClassicCredential"
                                when 'azure_rm' then "#{provider_module}::AutomationManager::AzureCredential"
                                when 'openstack' then "#{provider_module}::AutomationManager::OpenstackCredential"
                                else "#{provider_module}::AutomationManager::Credential"
                                end
      inventory_object.options = inventory_object.type.constantize::EXTRA_ATTRIBUTES.keys.each_with_object({}) do |k, h|
        h[k] = credential.public_send(k)
      end
    end
  end
end
