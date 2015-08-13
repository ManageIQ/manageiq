class ManageIQ::Providers::Redhat::InfraManager::EventCatcher < ManageIQ::Providers::BaseManager::EventCatcher
  require_dependency 'manageiq/providers/redhat/infra_manager/event_catcher/runner'
end
