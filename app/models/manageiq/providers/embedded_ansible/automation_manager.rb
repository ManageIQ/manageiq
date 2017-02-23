class ManageIQ::Providers::EmbeddedAnsible::AutomationManager < ManageIQ::Providers::EmbeddedAutomationManager
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
  require_nested :Job
  require_nested :Playbook

  def self.ems_type
    @ems_type ||= "embedded_ansible_automation".freeze
  end

  def self.description
    @description ||= "Embedded Ansible Automation".freeze
  end
end
