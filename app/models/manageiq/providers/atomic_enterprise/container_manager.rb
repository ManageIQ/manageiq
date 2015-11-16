class ManageIQ::Providers::AtomicEnterprise::ContainerManager < ManageIQ::Providers::ContainerManager
  include ManageIQ::Providers::Openshift::ContainerManagerMixin

  require_nested :EventCatcher
  require_nested :EventParser
  require_nested :MetricsCollectorWorker
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Refresher

  def self.ems_type
    @ems_type ||= "atomic_enterprise".freeze
  end

  def self.description
    @description ||= "Atomic Enterprise".freeze
  end

  def self.event_monitor_class
    ManageIQ::Providers::AtomicEnterprise::ContainerManager::EventCatcher
  end
end
