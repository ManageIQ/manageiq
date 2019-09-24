FactoryBot.define do
  factory :metric_rollup do
    timestamp { Time.now.utc }
    trait :with_data do
      cpu_usage_rate_average            { 50.0 }
      cpu_usagemhz_rate_average         { 50.0 }
      derived_vm_numvcpus               { 1.0 }
      derived_memory_available          { 1000.0 }
      derived_memory_used               { 100.0 }
      disk_usage_rate_average           { 100.0 }
      net_usage_rate_average            { 25.0 }
      derived_vm_used_disk_storage      { 1.0.gigabytes }
      derived_vm_allocated_disk_storage { 4.0.gigabytes }
    end

    trait :in_other_region do
      other_region
    end
  end

  factory :metric_rollup_vm_hr, :parent => :metric_rollup, :class => :MetricRollup do
    capture_interval_name { "hourly" }
    resource_type         { "VmOrTemplate" }
  end

  factory :metric_rollup_vm_daily, :parent => :metric_rollup, :class => :MetricRollup do
    capture_interval_name { "daily" }
    resource_type         { "VmOrTemplate" }
  end

  factory :metric_rollup_host_hr, :parent => :metric_rollup, :class => :MetricRollup do
    capture_interval_name { "hourly" }
    resource_type         { "Host" }
  end

  factory :metric_rollup_host_daily, :parent => :metric_rollup, :class => :MetricRollup do
    capture_interval_name { "daily" }
    resource_type         { "Host" }
  end

  factory :metric_rollup_cm_hr, :parent => :metric_rollup, :class => :MetricRollup do
    capture_interval_name { "hourly" }
    resource_type         { "ExtManagementSystem" }
  end

  factory :metric_rollup_cm_daily, :parent => :metric_rollup, :class => :MetricRollup do
    capture_interval_name { "daily" }
    resource_type         { "ExtManagementSystem" }
  end

  factory :metric_rollup_storage_hr, :parent => :metric_rollup, :class => :MetricRollup do
    capture_interval_name { "hourly" }
    resource_type         { "Storage" }
  end
end
