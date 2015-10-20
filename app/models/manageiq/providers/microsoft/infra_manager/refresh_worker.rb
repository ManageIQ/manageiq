class ManageIQ::Providers::Microsoft::InfraManager::RefreshWorker < ::MiqEmsRefreshWorker
  require_nested :Runner

  def self.ems_class
    ManageIQ::Providers::Microsoft::InfraManager
  end
end
