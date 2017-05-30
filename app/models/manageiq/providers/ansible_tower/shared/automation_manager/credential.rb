module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::Credential
  extend ActiveSupport::Concern

  include ProviderObjectMixin

  module ClassMethods
    def provider_collection(manager)
      manager.with_provider_connection do |connection|
        connection.api.credentials
      end
    end

    def provider_params(params)
      params[:username] = params.delete(:userid) if params.include?(:userid)
      params[:kind] = self::TOWER_KIND
      params
    end

    def process_secrets(params, decrypt = false)
      if decrypt
        Vmdb::Settings.decrypt_passwords!(params)
      else
        Vmdb::Settings.encrypt_passwords!(params)
      end
    end

    def notify_on_provider_interaction?
      true
    end
  end

  def provider_object(connection = nil)
    (connection || connection_source.connect).api.credentials.find(manager_ref)
  end

  COMMON_ATTRIBUTES = {}.freeze
  EXTRA_ATTRIBUTES = {}.freeze
  API_ATTRIBUTES = COMMON_ATTRIBUTES.merge(EXTRA_ATTRIBUTES).freeze

  FRIENDLY_NAME = 'Ansible Tower Credential'.freeze
end
