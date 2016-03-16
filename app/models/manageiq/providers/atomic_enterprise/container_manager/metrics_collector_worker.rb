module ManageIQ::Providers
  class AtomicEnterprise::ContainerManager::MetricsCollectorWorker < BaseManager::MetricsCollectorWorker
    require_nested :Runner

    self.default_queue_name = "atomic_enterprise"

    def friendly_name
      @friendly_name ||= _("C&U Metrics Collector for Atomic Enterprise")
    end

    def self.ems_class
      ManageIQ::Providers::AtomicEnterprise::ContainerManager
    end
  end
end
