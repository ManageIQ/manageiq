class ManageIQ::Providers::AnsibleTower::AutomationManager < ManageIQ::Providers::ExternalAutomationManager
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager

  require_nested :AmazonCredential
  require_nested :AzureCredential
  require_nested :CloudCredential
  require_nested :GoogleCredential
  require_nested :MachineCredential
  require_nested :NetworkCredential
  require_nested :OpenstackCredential
  require_nested :RackspaceCredential
  require_nested :Satellite6Credential
  require_nested :VmwareCredential

  require_nested :ConfigurationScript
  require_nested :ConfiguredSystem
  require_nested :EventCatcher
  require_nested :EventParser
  require_nested :Job
  require_nested :Playbook
  require_nested :Refresher
  require_nested :RefreshWorker

  def self.ems_type
    @ems_type ||= "ansible_tower_automation".freeze
  end

  def self.description
    @description ||= "Ansible Tower Automation".freeze
  end
end
