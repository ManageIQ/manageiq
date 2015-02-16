class MiqEmsMetricsCollectorWorkerOpenstackInfra < MiqEmsMetricsCollectorWorker
  self.default_queue_name = "openstack_infra"

  def friendly_name
    @friendly_name ||= "C&U Metrics Collector for OpenstackInfra"
  end

  def self.ems_class
    EmsOpenstackInfra
  end
end
