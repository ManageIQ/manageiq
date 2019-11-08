class ManageIQ::Providers::CloudManager::MetricsCapture < ManageIQ::Providers::BaseManager::MetricsCapture
  def capture_ems_targets(options = {})
    Metric::Targets.capture_cloud_targets([ems], options)
  end
end
