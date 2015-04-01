module Metric::CiMixin::Capture::Kubernetes
  def perf_collect_metrics_kubernetes(interval_name, start_time = nil,
                                      end_time = nil)
    $log.info("#{log_header} Collecting Kubernetes metrics - interval: " \
              "[#{interval_name}], start_time: [#{start_time}], " \
              "end_time: [#{end_time}]")
    [{ems_ref => {}}, {ems_ref => {}}]
  end

  private

  def log_header
    "MIQ(#{self.class.name}.perf_collect_metrics_kubernetes) id: [#{id}] " \
    "name: [#{name}]"
  end
end
