FactoryGirl.define do
  factory :chargeback_rate_detail do
    group   "unknown"
    source  "unknown"
    chargeback_rate

    trait :euro do
      detail_currency { FactoryGirl.create(:chargeback_rate_detail_currency_EUR) }
    end

    trait :bytes do
      detail_measure { FactoryGirl.create(:chargeback_rate_detail_measure_bytes) }
    end

    trait :tiers do
      chargeback_tiers { [FactoryGirl.create(:chargeback_tier)] }
    end

    trait :tiers_with_three_intervals do
      chargeback_tiers do
        [
          FactoryGirl.create(:chargeback_tier_first_of_three),
          FactoryGirl.create(:chargeback_tier_second_of_three),
          FactoryGirl.create(:chargeback_tier_third_of_three)
        ]
      end
    end
  end

  factory :chargeback_rate_detail_cpu_used, :parent => :chargeback_rate_detail do
    description "Used CPU in MHz"
    group       "cpu"
    source      "used"
    metric      "cpu_usagemhz_rate_average"
    per_unit    "megahertz"
  end

  factory :chargeback_rate_detail_cpu_cores_used, :parent => :chargeback_rate_detail do
    description "Used CPU in Cores"
    group       "cpu"
    source      "used"
    metric      "cpu_usage_rate_average"
    per_unit    "cores"
  end

  factory :chargeback_rate_detail_cpu_allocated, :parent => :chargeback_rate_detail do
    description "Allocated CPU Count"
    group       "cpu"
    source      "allocated"
    metric      "derived_vm_numvcpus"
    per_unit    "cpu"
    per_time    "daily"
  end

  factory :chargeback_rate_detail_memory_allocated, :parent => :chargeback_rate_detail do
    description "Allocated Memory in MB"
    group       "memory"
    source      "allocated"
    metric      "derived_memory_available"
    per_unit    "megabytes"
    per_time    "daily"
  end

  factory :chargeback_rate_detail_memory_used, :parent => :chargeback_rate_detail do
    per_unit    "megabytes"
    description "Used Memory in MB"
    group       "memory"
    source      "used"
    metric      "derived_memory_used"
  end

  factory :chargeback_rate_detail_disk_io_used, :parent => :chargeback_rate_detail do
    description "Used Disk I/O in KBps"
    group       "disk_io"
    source      "used"
    metric      "disk_usage_rate_average"
    per_unit    "kbps"
  end

  factory :chargeback_rate_detail_net_io_used, :parent => :chargeback_rate_detail do
    description "Used Network I/O in KBps"
    group       "net_io"
    source      "used"
    metric      "net_usage_rate_average"
    per_unit    "kbps"
  end

  factory :chargeback_rate_detail_storage_used, :parent => :chargeback_rate_detail do
    description "Used Disk Storage in Bytes"
    group       "storage"
    source      "used"
    metric      "derived_vm_used_disk_storage"
    per_unit    "gigabytes"
  end

  factory :chargeback_rate_detail_storage_allocated, :parent => :chargeback_rate_detail do
    description "Allocated Disk Storage in Bytes"
    group       "storage"
    source      "allocated"
    metric      "derived_vm_allocated_disk_storage"
    per_unit    "gigabytes"
  end

  factory :chargeback_rate_detail_fixed_compute_cost, :parent => :chargeback_rate_detail do
    description "Fixed Compute Cost 1"
    group       "fixed"
    source      "compute_1"
    per_time    "daily"
  end

  factory :chargeback_rate_detail_memory_allocated_with_tiers, :parent => :chargeback_rate_detail_memory_allocated,
                                                               :traits => [:euro, :bytes, :tiers_with_three_intervals]

  factory :chargeback_rate_detail_memory_used_with_tiers, :parent => :chargeback_rate_detail_memory_used,
                                                          :traits => [:euro, :bytes, :tiers]
end
