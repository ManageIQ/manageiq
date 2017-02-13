module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager
  extend ActiveSupport::Concern

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
    private

    def connection_source(options = {})
      options[:connection_source] || self
    end
  end

  def image_name
    "ansible_tower_configuration"
  end
end
