FactoryGirl.define do
  factory :chargeback_rate_detail, :traits => [:bytes] do
    group   "unknown"
    source  "unknown"
    chargeback_rate
    detail_currency { FactoryGirl.create(:chargeback_rate_detail_currency) }

    trait :bytes do
      detail_measure { FactoryGirl.create(:chargeback_rate_detail_measure_bytes) }
    end

    transient do
      tiers_params nil
    end

    trait :tiers do
      after(:create) do |chargeback_rate_detail, evaluator|
        if evaluator.tiers_params
          evaluator.tiers_params.each do |tier|
            chargeback_rate_detail.chargeback_tiers << FactoryGirl.create(*[:chargeback_tier, tier])
          end
        else
          chargeback_rate_detail.chargeback_tiers << FactoryGirl.create(:chargeback_tier)
        end
      end
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

  trait :used do
    source "used"
  end

  trait :fixed do
    group "fixed"
  end

  trait :allocated do
    source "allocated"
  end

  trait :cpu do
    group "cpu"
  end

  trait :storage_group do
    group "storage"
  end

  trait :memory do
    group "memory"
  end

  trait :megabytes do
    per_unit "megabytes"
  end

  trait :kbps do
    per_unit "kbps"
  end

  trait :gigabytes do
    per_unit "gigabytes"
  end

  trait :daily do
    per_time "daily"
  end

  trait :hourly do
    per_time "hourly"
  end

  factory :chargeback_rate_detail_cpu_used, :traits => [:used, :cpu], :parent => :chargeback_rate_detail do
    description "Used CPU in MHz"
    metric      "cpu_usagemhz_rate_average"
    per_unit    "megahertz"
  end

  factory :chargeback_rate_detail_cpu_cores_used, :traits => [:used], :parent => :chargeback_rate_detail do
    description "Used CPU in Cores"
    metric      "cpu_usage_rate_average"
    group       "cpu_cores"
    per_unit    "cores"
  end

  factory :chargeback_rate_detail_cpu_allocated, :traits => [:allocated, :cpu, :daily],
                                                 :parent => :chargeback_rate_detail do
    description "Allocated CPU Count"
    metric      "derived_vm_numvcpus"
    per_unit    "cpu"
  end

  factory :chargeback_rate_detail_memory_allocated, :traits => [:allocated, :memory, :megabytes, :daily],
                                                    :parent => :chargeback_rate_detail do
    description "Allocated Memory in MB"
    metric      "derived_memory_available"
  end

  factory :chargeback_rate_detail_memory_used, :traits => [:used, :memory, :megabytes, :hourly],
                                               :parent => :chargeback_rate_detail do
    description "Used Memory in MB"
    metric      "derived_memory_used"
  end

  factory :chargeback_rate_detail_disk_io_used, :traits => [:used, :kbps], :parent => :chargeback_rate_detail do
    description "Used Disk I/O in KBps"
    group       "disk_io"
    metric      "disk_usage_rate_average"
  end

  factory :chargeback_rate_detail_net_io_used, :traits => [:used, :kbps], :parent => :chargeback_rate_detail do
    description "Used Network I/O in KBps"
    group       "net_io"
    metric      "net_usage_rate_average"
  end

  factory :chargeback_rate_detail_storage_used, :traits => [:used, :storage_group, :gigabytes],
                                                :parent => :chargeback_rate_detail do
    description "Used Disk Storage in Bytes"
    metric      "derived_vm_used_disk_storage"
  end

  factory :chargeback_rate_detail_storage_allocated, :traits => [:allocated, :storage_group, :gigabytes],
                                                     :parent => :chargeback_rate_detail do
    description "Allocated Disk Storage in Bytes"
    metric      "derived_vm_allocated_disk_storage"
  end

  factory :chargeback_rate_detail_fixed_compute_cost, :traits => [:fixed, :daily], :parent => :chargeback_rate_detail do
    sequence(:description) { |n| "Fixed Compute Cost #{n}" }
    sequence(:source)      { |n| "compute_#{n}" }
  end

  factory :chargeback_rate_detail_fixed_storage_cost, :traits => [:fixed, :daily], :parent => :chargeback_rate_detail do
    sequence(:description) { |n| "Fixed Storage Cost #{n}" }
    sequence(:source)      { |n| "storage_#{n}" }
  end
end
