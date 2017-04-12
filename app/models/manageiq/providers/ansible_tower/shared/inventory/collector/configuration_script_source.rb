module ManageIQ::Providers::AnsibleTower::Shared::Inventory::Collector::ConfigurationScriptSource
  def connection
    @connection ||= manager.connect
  end

  def projects
    target.refresh_in_provider
    [project]
  end

  def credentials
    # checking project.credential due to https://github.com/ansible/ansible_tower_client_ruby/issues/68
    credential_id = project.try(:credential_id)
    credential_id.present? ? [connection.api.credentials.find(credential_id)] : []
  end

  def project
    @project ||= connection.api.projects.find(target.manager_ref)
  end
end
