class MiqEmsMetricsCollectorWorkerRedhat < MiqEmsMetricsCollectorWorker
  self.default_queue_name = "redhat"

  def friendly_name
    @friendly_name ||= "C&U Metrics Collector for RHEV"
  end

  def self.ems_class
    EmsRedhat
  end
end
