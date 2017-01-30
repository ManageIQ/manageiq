class ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScriptSource < ConfigurationScriptSource
  extend ApiCreate

  def provider_object(connection = nil)
    (connection || connection_source.connect).api.projects.find(manager_ref)
  end
end
