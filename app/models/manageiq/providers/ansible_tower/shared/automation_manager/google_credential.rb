module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::GoogleCredential
  extend ActiveSupport::Concern

  COMMON_ATTRIBUTES = {
  }.freeze

  EXTRA_ATTRIBUTES = {
  }.freeze

  API_ATTRIBUTES = COMMON_ATTRIBUTES.merge(EXTRA_ATTRIBUTES).freeze

  API_OPTIONS = {
    :type       => 'cloud',
    :label      => N_('Google'),
    :attributes => API_ATTRIBUTES
  }.freeze
end
