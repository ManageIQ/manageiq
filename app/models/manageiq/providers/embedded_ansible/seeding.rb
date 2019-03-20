module ManageIQ::Providers::EmbeddedAnsible::Seeding
  extend ActiveSupport::Concern

  module ClassMethods
    def seed
      provider = ManageIQ::Providers::EmbeddedAnsible::Provider.in_my_region.first_or_initialize
      provider.update_attributes!(
        :name => "Embedded Ansible",
      )

      manager = provider.automation_manager || provider.build_automation_manager
      manager.update_attributes!(
        :name => "Embedded Ansible",
        :zone => MiqServer.my_server.zone,  # TODO: Do we even need zone?
      )

      manager.authentications.create_with(
        :type => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager::MachineCredential",
      ).find_or_create_by!(
        :name => "#{Vmdb::Appliance.PRODUCT_NAME} Default Credential",
      )
    end
  end
end
