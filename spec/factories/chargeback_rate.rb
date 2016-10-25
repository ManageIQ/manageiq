FactoryGirl.define do
  factory :chargeback_rate do
    guid                   { MiqUUID.new_guid }
    sequence(:description) { |n| "Chargeback Rate ##{n}" }
    rate_type 'Compute'

    transient do
      per_time 'hourly'
    end

    trait :with_details do
      chargeback_rate_details do
        [FactoryGirl.create(:chargeback_rate_detail_memory_allocated, :tiers_with_three_intervals),
         FactoryGirl.create(:chargeback_rate_detail_memory_used, :tiers)]
      end
    end

    trait :with_compute_details do
      after(:create) do |chargeback_rate, evaluator|
        %i(
          chargeback_rate_detail_cpu_used
          chargeback_rate_detail_cpu_allocated
          chargeback_rate_detail_cpu_cores_used
          chargeback_rate_detail_disk_io_used
          chargeback_rate_detail_fixed_compute_cost
          chargeback_rate_detail_fixed_compute_cost
          chargeback_rate_detail_memory_allocated
          chargeback_rate_detail_memory_used
          chargeback_rate_detail_net_io_used
        ).each do |factory_name|
          chargeback_rate.chargeback_rate_details << FactoryGirl.create(factory_name,
                                                                        :tiers_with_three_intervals,
                                                                        :per_time => evaluator.per_time)
        end
      end
    end

    trait :with_storage_details do
      rate_type 'Storage'

      after(:create) do |chargeback_rate, evaluator|
        %i(
          chargeback_rate_detail_storage_used
          chargeback_rate_detail_storage_allocated
          chargeback_rate_detail_fixed_storage_cost
          chargeback_rate_detail_fixed_storage_cost
        ).each do |factory_name|
          chargeback_rate.chargeback_rate_details << FactoryGirl.create(factory_name,
                                                                        :tiers_with_three_intervals,
                                                                        :per_time => evaluator.per_time)
        end
      end
    end
  end
end
