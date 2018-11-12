FactoryGirl.define do
  factory :chargeback_rate_detail do
    chargeback_rate
    detail_currency { FactoryGirl.create(:chargeback_rate_detail_currency) }

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

  factory :chargeback_rate_detail_cpu_used, :parent => :chargeback_rate_detail do
    per_unit    "megahertz"
    chargeable_field { FactoryGirl.build(:chargeable_field_cpu_used) }
  end

  factory :chargeback_rate_detail_cpu_cores_used, :parent => :chargeback_rate_detail do
    per_unit    "cores"
    chargeable_field { FactoryGirl.build(:chargeable_field_cpu_cores_used) }
  end

  factory :chargeback_rate_detail_cpu_cores_allocated, :parent => :chargeback_rate_detail do
    per_unit    "cores"
    chargeable_field { FactoryGirl.build(:chargeable_field_cpu_cores_allocated) }
  end

  factory :chargeback_rate_detail_cpu_allocated, :traits => [:daily],
                                                 :parent => :chargeback_rate_detail do
    per_unit    "cpu"
    chargeable_field { FactoryGirl.build(:chargeable_field_cpu_allocated) }
  end

  factory :chargeback_rate_detail_memory_allocated, :traits => [:megabytes, :daily],
                                                    :parent => :chargeback_rate_detail do
    chargeable_field { FactoryGirl.build(:chargeable_field_memory_allocated) }
  end

  factory :chargeback_rate_detail_memory_used, :traits => [:megabytes, :hourly],
                                               :parent => :chargeback_rate_detail do
    chargeable_field { FactoryGirl.build(:chargeable_field_memory_used) }
  end

  factory :chargeback_rate_detail_disk_io_used, :traits => [:kbps], :parent => :chargeback_rate_detail do
    chargeable_field { FactoryGirl.build(:chargeable_field_disk_io_used) }
  end

  factory :chargeback_rate_detail_net_io_used, :traits => [:kbps], :parent => :chargeback_rate_detail do
    chargeable_field { FactoryGirl.build(:chargeable_field_net_io_used) }
  end

  factory :chargeback_rate_detail_storage_used, :traits => [:gigabytes],
                                                :parent => :chargeback_rate_detail do
    chargeable_field { FactoryGirl.build(:chargeable_field_storage_used) }
  end

  factory :chargeback_rate_detail_storage_allocated, :traits => [:gigabytes],
                                                     :parent => :chargeback_rate_detail do
    chargeable_field { FactoryGirl.build(:chargeable_field_storage_allocated) }
  end

  factory :chargeback_rate_detail_fixed_compute_cost, :traits => [:daily], :parent => :chargeback_rate_detail do
    chargeable_field { FactoryGirl.build(:chargeable_field_fixed_compute_1) }
  end
end
