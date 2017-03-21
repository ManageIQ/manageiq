class ManageIQ::Providers::AnsibleTower::Provider < ::Provider
  include ManageIQ::Providers::AnsibleTower::Shared::Provider

  has_one :automation_manager,
          :foreign_key => "provider_id",
          :class_name  => "ManageIQ::Providers::AnsibleTower::AutomationManager",
          :dependent   => :destroy,
          :autosave    => true
end
