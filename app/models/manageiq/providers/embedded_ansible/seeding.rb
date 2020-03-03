module ManageIQ::Providers::EmbeddedAnsible::Seeding
  extend ActiveSupport::Concern

  module ClassMethods
    def seed
      provider = ManageIQ::Providers::EmbeddedAnsible::Provider.in_my_region.first_or_initialize
      provider.update!(
        :name => "Embedded Ansible",
        :zone => provider.zone || MiqServer.my_server.zone
      )

      manager = provider.automation_manager
      manager.update!(
        :name => "Embedded Ansible",
        :zone => MiqServer.my_server.zone # TODO: Do we even need zone?
      )

      ManageIQ::Providers::EmbeddedAnsible::AutomationManager::MachineCredential.find_or_create_by!(
        :name     => "#{Vmdb::Appliance.PRODUCT_NAME} Default Credential",
        :resource => manager
      )

      Ansible::Content.consolidate_plugin_playbooks
    end
  end
end
