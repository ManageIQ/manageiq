class MiqEmsMetricsCollectorWorkerVmware < MiqEmsMetricsCollectorWorker
  self.default_queue_name = "vmware"

  def friendly_name
    @friendly_name ||= "C&U Metrics Collector for vCenter"
  end

  def self.ems_class
    EmsVmware
  end
end
