class ManageIQ::Providers::AnsibleTower::AutomationManager < ManageIQ::Providers::ExternalAutomationManager
  require_nested :ConfigurationScript
  require_nested :ConfigurationScriptSource
  require_nested :ConfiguredSystem
  require_nested :Refresher
  require_nested :RefreshWorker
  require_nested :Job

  has_many :configuration_script_sources,
           :class_name  => 'ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScriptSource',
           :foreign_key => :manager_id,
           :inverse_of  => :manager

  has_many :playbooks, :through    => :configuration_script_sources,
                       :class_name => 'ManageIQ::Providers::AnsibleTower::AutomationManager::Playbook',
                       :source     => :configuration_script_payloads

  include ProcessTasksMixin
  delegate :authentications,
           :authentication_check,
           :authentication_status,
           :authentication_status_ok?,
           :connect,
           :missing_credentials?,
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
