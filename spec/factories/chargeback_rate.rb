FactoryGirl.define do
  factory :chargeback_rate do
    guid                   { MiqUUID.new_guid }
    sequence(:description) { |n| "Chargeback Rate ##{n}" }
    rate_type 'Compute'

    trait :with_details do
      chargeback_rate_details do
        [FactoryGirl.create(:chargeback_rate_detail_memory_allocated, :tiers_with_three_intervals),
         FactoryGirl.create(:chargeback_rate_detail_memory_used, :tiers)]
      end
    end
  end
end
