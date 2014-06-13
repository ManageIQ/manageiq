FactoryGirl.define do
  factory :metric_vm_rt, :class => :Metric do
    capture_interval_name "realtime"
    resource_type         "VmOrTemplate"
  end

  factory :metric_rollup_vm_hr, :class => :MetricRollup do
    capture_interval_name "hourly"
    resource_type         "VmOrTemplate"
  end

  factory :metric_rollup_vm_daily, :class => :MetricRollup do
    capture_interval_name "daily"
    resource_type         "VmOrTemplate"
  end

  factory :metric_host_rt, :class => :Metric do
    capture_interval_name "realtime"
    resource_type         "Host"
  end

  factory :metric_rollup_host_hr, :class => :MetricRollup do
    capture_interval_name "hourly"
    resource_type         "Host"
  end
end
