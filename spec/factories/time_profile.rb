FactoryBot.define do
  factory :time_profile do
    sequence(:description) { |n| "Time Profile #{seq_padded_for_sorting(n)}" }

    trait :in_other_region do
      other_region
    end
  end

  factory :time_profile_with_rollup, :parent => :time_profile do
    rollup_daily_metrics { true }
  end

  factory :time_profile_utc, :parent => :time_profile_with_rollup do
    tz { "UTC" }
  end
end
