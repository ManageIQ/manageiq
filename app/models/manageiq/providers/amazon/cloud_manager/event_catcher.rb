class ManageIQ::Providers::Amazon::CloudManager::EventCatcher < ManageIQ::Providers::BaseManager::EventCatcher
  require_dependency 'manageiq/providers/amazon/cloud_manager/event_catcher/runner'
end
