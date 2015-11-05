module ManageIQ::Providers
  class OpenshiftEnterprise::ContainerManager::MetricsCollectorWorker < BaseManager::MetricsCollectorWorker
    require_nested :Runner

    self.default_queue_name = "openshift_enterprise"

    def friendly_name
      @friendly_name ||= "C&U Metrics Collector for Openshift Enterprise"
    end

    def self.ems_class
      ManageIQ::Providers::OpenshiftEnterprise::ContainerManager
    end
  end
end
