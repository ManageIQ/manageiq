module ManageIQ::Providers
  class Kubernetes::ContainerManager::MetricsCollectorWorker < BaseManager::MetricsCollectorWorker
    require_nested :Runner

    self.default_queue_name = "kubernetes"

    def friendly_name
      @friendly_name ||= "C&U Metrics Collector for Kubernetes"
    end

    def self.ems_class
      ManageIQ::Providers::Kubernetes::ContainerManager
    end
  end
end
