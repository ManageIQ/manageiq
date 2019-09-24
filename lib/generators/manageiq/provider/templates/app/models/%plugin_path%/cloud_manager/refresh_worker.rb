class <%= class_name %>::CloudManager::RefreshWorker < MiqEmsRefreshWorker
  require_nested :Runner

  def self.ems_class
    parent
  end
end
