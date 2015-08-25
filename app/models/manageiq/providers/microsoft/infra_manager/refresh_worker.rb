class ManageIQ::Providers::Microsoft::InfraManager::RefreshWorker < ::MiqEmsRefreshWorker
  require_dependency 'manageiq/providers/microsoft/infra_manager/refresh_worker/runner'

  def self.ems_class
    ManageIQ::Providers::Microsoft::InfraManager
  end
end
