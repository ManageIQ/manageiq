module ManageIQ::Providers
  class BaseManager < ExtManagementSystem
    require_nested :Refresher

    include SupportsFeatureMixin
    supports_not :provisioning # via automate
    supports_not :regions      # as in ManageIQ::Providers::<Type>::Regions
    supports_not :smartstate_analysis
    supports :vm_destroy do
      byebug
      unsupported_reason_add(:vm_destroy, _("Provider doesn't support vm_destroy")) unless self.respond_to?(:vm_destroy)
    end

    def self.metrics_collector_queue_name
      self::MetricsCollectorWorker.default_queue_name
    end

    def metrics_collector_queue_name
      self.class.metrics_collector_queue_name
    end

    def ext_management_system
      self
    end

    def refresher
      self.class::Refresher
    end
  end
end
