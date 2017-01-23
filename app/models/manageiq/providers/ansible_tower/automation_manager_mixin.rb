module ManageIQ::Providers::AnsibleTower::AutomationManagerMixin
  extend ActiveSupport::Concern

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

  module ClassMethods
    def ems_type
      @ems_type ||= "ansible_tower_automation_manager".freeze
    end

    def description
      @description ||= "Ansible Tower Automation Manager".freeze
    end

    private

    def connection_source(options = {})
      options[:connection_source] || self
    end
  end


  def image_name
    "ansible_tower_configuration"
  end

end
