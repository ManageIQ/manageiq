class ManageIQ::Providers::EmbeddedAnsible::AutomationManager < ManageIQ::Providers::EmbeddedAutomationManager
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager

  require_nested :Credential
  require_nested :AmazonCredential
  require_nested :AzureCredential
  require_nested :CloudCredential
  require_nested :GoogleCredential
  require_nested :MachineCredential
  require_nested :NetworkCredential
  require_nested :OpenstackCredential
  require_nested :RackspaceCredential
  require_nested :ScmCredential
  require_nested :Satellite6Credential
  require_nested :VmwareCredential

  require_nested :ConfigurationScript
  require_nested :Project
  require_nested :ConfiguredSystem
  require_nested :EventCatcher
  require_nested :EventParser
  require_nested :Inventory
  require_nested :Job
  require_nested :Playbook
  require_nested :Refresher
  require_nested :RefreshWorker
  has_many :projects, :foreign_key => "manager_id"

  def self.ems_type
    @ems_type ||= "embedded_ansible_automation".freeze
  end

  def self.description
    @description ||= "Embedded Ansible Automation".freeze
  end
end
