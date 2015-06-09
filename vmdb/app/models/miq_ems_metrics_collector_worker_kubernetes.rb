class MiqEmsMetricsCollectorWorkerKubernetes < MiqEmsMetricsCollectorWorker
  self.default_queue_name = "kubernetes"

  def friendly_name
    @friendly_name ||= "C&U Metrics Collector for Kubernetes"
  end

  def self.ems_class
    EmsKubernetes
  end
end
