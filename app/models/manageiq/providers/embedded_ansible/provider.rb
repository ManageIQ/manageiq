class ManageIQ::Providers::EmbeddedAnsible::Provider < ::Provider
  include ManageIQ::Providers::AnsibleTower::Shared::Provider

  include_concern 'DefaultAnsibleObjects'

  has_one :automation_manager,
          :foreign_key => "provider_id",
          :class_name  => "ManageIQ::Providers::EmbeddedAnsible::AutomationManager",
          :dependent   => :destroy,
          :autosave    => true

  def self.raw_connect(base_url, username, password, verify_ssl)
    raise StandardError, 'Embedded ansible is disabled' unless role_enabled?
    super
  end

  def self.role_enabled?
    MiqServer.all.any? { |x| x.has_active_role?('embedded_ansible') }
  end
  private_class_method :role_enabled?
end
