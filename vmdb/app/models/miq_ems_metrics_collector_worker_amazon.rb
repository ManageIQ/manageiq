class MiqEmsMetricsCollectorWorkerAmazon < MiqEmsMetricsCollectorWorker
  self.default_queue_name = "amazon"

  def friendly_name
    @friendly_name ||= "C&U Metrics Collector for Amazon"
  end

  def self.ems_class
    EmsAmazon
  end
end
