FactoryGirl.define do
  factory :chargeback_rate_detail, :traits => [:euro, :bytes] do
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

  trait :used do
    source "used"
  end

  trait :allocated do
    source "allocated"
  end

  trait :memory do
    group "memory"
  end

  trait :megabytes do
    per_unit "megabytes"
  end

  trait :daily do
    per_time "daily"
  end

  trait :hourly do
    per_time "hourly"
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
end
