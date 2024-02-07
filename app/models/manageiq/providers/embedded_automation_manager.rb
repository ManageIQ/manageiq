class ManageIQ::Providers::EmbeddedAutomationManager < ManageIQ::Providers::AutomationManager
  supports :catalog

  def self.catalog_types
    {"generic_ansible_playbook" => N_("Ansible Playbook")}
  end
end
