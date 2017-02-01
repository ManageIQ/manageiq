class ManageIQ::Providers::EmbeddedAnsible::Provider < ::Provider
  include ManageIQ::Providers::AnsibleTower::ProviderMixin

  has_one :automation_manager,
          :foreign_key => "provider_id",
          :class_name  => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager",
          :dependent   => :destroy,
          :autosave    => true
end
