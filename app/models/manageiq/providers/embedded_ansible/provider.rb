class ManageIQ::Providers::EmbeddedAnsible::Provider < ::Provider
  include ManageIQ::Providers::AnsibleTower::Shared::Provider

  include_concern 'DefaultAnsibleObjects'

  has_one :automation_manager,
          :foreign_key => "provider_id",
          :class_name  => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager",
          :dependent   => :destroy, # to be removed after ansible_tower side code is updated
          :autosave    => true

  def self.raw_connect(base_url, username, password, verify_ssl)
    return super if MiqRegion.my_region.role_active?('embedded_ansible')
    raise MiqException::Error, 'Embedded ansible is disabled'
  end
end
