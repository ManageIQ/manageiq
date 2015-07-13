FactoryGirl.define do
  factory :metric_rollup do
    timestamp { Time.now.utc }
  end

  factory :metric_rollup_vm_hr, :parent => :metric_rollup, :class => :MetricRollup do
    capture_interval_name "hourly"
    resource_type         "VmOrTemplate"
  end

  factory :metric_rollup_vm_daily, :parent => :metric_rollup, :class => :MetricRollup do
    capture_interval_name "daily"
    resource_type         "VmOrTemplate"
  end

  factory :metric_rollup_host_hr, :parent => :metric_rollup, :class => :MetricRollup do
    capture_interval_name "hourly"
    resource_type         "Host"
  end
end
