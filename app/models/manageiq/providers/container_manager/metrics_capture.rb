class ManageIQ::Providers::ContainerManager::MetricsCapture < ManageIQ::Providers::BaseManager::MetricsCapture
  def capture_ems_targets(options = {})
    Metric::Targets.capture_container_targets([ems], options)
  end
end
