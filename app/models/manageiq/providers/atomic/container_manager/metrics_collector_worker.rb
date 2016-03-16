module ManageIQ::Providers
  class Atomic::ContainerManager::MetricsCollectorWorker < BaseManager::MetricsCollectorWorker
    require_nested :Runner

    self.default_queue_name = "atomic"

    def friendly_name
      @friendly_name ||= _("C&U Metrics Collector for Atomic")
    end

    def self.ems_class
      ManageIQ::Providers::Atomic::ContainerManager
    end
  end
end
