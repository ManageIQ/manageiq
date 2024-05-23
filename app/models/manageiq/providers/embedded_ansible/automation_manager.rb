class ManageIQ::Providers::EmbeddedAnsible::AutomationManager < ManageIQ::Providers::EmbeddedAutomationManager
  supports     :catalog
  supports_not :refresh_ems

  def self.ems_type
    @ems_type ||= "embedded_ansible_automation".freeze
  end

  def self.description
    @description ||= "Embedded Ansible Automation".freeze
  end

  def self.catalog_types
    {"generic_ansible_playbook" => N_("Ansible Playbook")}
  end
end
