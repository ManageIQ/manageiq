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

    def hide_secrets(params)
      params.each_with_object({}) do |attr, h|
        h[attr.first] = self::API_ATTRIBUTES[attr.first] && self::API_ATTRIBUTES[attr.first][:type] == :password ? '******' : attr.second
      end
    end
  end

  def provider_object(connection = nil)
    (connection || connection_source.connect).api.credentials.find(manager_ref)
  end

  COMMON_ATTRIBUTES = {}.freeze
  EXTRA_ATTRIBUTES = {}.freeze
  API_ATTRIBUTES = COMMON_ATTRIBUTES.merge(EXTRA_ATTRIBUTES).freeze
end
