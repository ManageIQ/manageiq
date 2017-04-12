module ManageIQ::Providers::AnsibleTower::Shared::Inventory::Parser::ConfigurationScriptSource
  include parent::AutomationManager

  def parse
    configuration_script_sources
    credentials
  end
end
