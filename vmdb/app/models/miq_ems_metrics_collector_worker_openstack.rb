class MiqEmsMetricsCollectorWorkerOpenstack < MiqEmsMetricsCollectorWorker
  self.default_queue_name = "openstack"

  def friendly_name
    @friendly_name ||= "C&U Metrics Collector for Openstack"
  end

  def self.ems_class
    EmsOpenstack
  end
end
