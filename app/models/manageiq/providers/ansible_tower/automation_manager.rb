class ManageIQ::Providers::AnsibleTower::AutomationManager < ManageIQ::Providers::ExternalAutomationManager
  require_nested :ConfigurationScript
  require_nested :ConfiguredSystem
  require_nested :Refresher
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Job

  include ProcessTasksMixin
  delegate :authentications,
           :authentication_check,
           :authentication_status,
           :authentication_status_ok?,
           :connect,
           :verify_credentials,
           :with_provider_connection,
           :to => :provider

  def self.ems_type
    @ems_type ||= "ansible_tower_automation".freeze
  end

  def self.description
    @description ||= "Ansible Tower Automation".freeze
  end

  def image_name
    "ansible_tower_automation"
  end

  private

  def connection_source(options = {})
    options[:connection_source] || self
  end
end
