class <%= class_name %>::<%= manager_type %>::MetricsCollectorWorker < ManageIQ::Providers::BaseManager::MetricsCollectorWorker
  require_nested :Runner

  self.default_queue_name = "<%= provider_name %>"

  def friendly_name
    @friendly_name ||= "C&U Metrics Collector for <%= class_name %>"
  end
end
