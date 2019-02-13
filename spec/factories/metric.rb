FactoryBot.define do
  factory :metric do
    timestamp { Time.now.utc }
  end

  factory :metric_vm_rt, :parent => :metric, :class => :Metric do
    capture_interval_name { "realtime" }
    resource_type         { "VmOrTemplate" }
  end

  factory :metric_host_rt, :parent => :metric, :class => :Metric do
    capture_interval_name { "realtime" }
    resource_type         { "Host" }
  end

  factory :metric_container_node_rt, :parent => :metric, :class => :Metric do
    capture_interval_name { "realtime" }
    resource_type         { "ContainerNode" }
  end
end
