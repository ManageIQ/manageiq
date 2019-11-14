class <%= class_name %>::CloudManager::RefreshWorker < MiqEmsRefreshWorker
  require_nested :Runner
end
