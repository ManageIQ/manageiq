class ManageIQ::Providers::EmbeddedAnsible::Provider < ::Provider
  include_concern 'DefaultAnsibleObjects'

  has_one :automation_manager,
          :foreign_key => "provider_id",
          :class_name  => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager",
          :dependent   => :destroy, # to be removed after ansible_tower side code is updated
          :autosave    => true
end
