class ManageIQ::Providers::Openstack::CloudManager::MetricsCollectorWorker < ::MiqEmsMetricsCollectorWorker
  require_nested :Runner

  self.default_queue_name = "openstack"

  def friendly_name
    @friendly_name ||= "C&U Metrics Collector for Openstack"
  end

  def self.ems_class
    ManageIQ::Providers::Openstack::CloudManager
  end
end
