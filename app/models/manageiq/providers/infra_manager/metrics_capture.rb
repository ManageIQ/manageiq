class ManageIQ::Providers::InfraManager::MetricsCapture < ManageIQ::Providers::BaseManager::MetricsCapture
  def capture_ems_targets(options = {})
    Metric::Targets.capture_infra_targets([ems], options)
  end
end
