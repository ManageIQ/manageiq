class ManageIQ::Providers::AnsibleTower::AutomationManager < ManageIQ::Providers::ExternalAutomationManager
  include ManageIQ::Providers::AnsibleTower::AutomationManagerMixin

  def self.ems_type
    @ems_type ||= "ansible_tower_automation".freeze
  end

  def self.description
    @description ||= "Ansible Tower Automation".freeze
  end
end
