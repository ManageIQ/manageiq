class <%= class_name %>::<%= manager_type %>::EventCatcher < ManageIQ::Providers::BaseManager::EventCatcher
  require_nested :Runner
end
