class <%= class_name %>::<%= manager_type %>::RefreshWorker < MiqEmsRefreshWorker
  require_nested :Runner
end
