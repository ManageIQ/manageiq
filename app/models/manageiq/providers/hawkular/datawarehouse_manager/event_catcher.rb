class ManageIQ::Providers::Hawkular::DatawarehouseManager::EventCatcher < ManageIQ::Providers::BaseManager::EventCatcher
  require_nested :Runner

  def self.settings_name
    :event_catcher_hawkular_datawarehouse
  end
end
