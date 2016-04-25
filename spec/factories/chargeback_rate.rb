FactoryGirl.define do
  factory :chargeback_rate do
    guid        { MiqUUID.new_guid }
    description 'foo'
    rate_type 'Compute'
  end

  factory :chargeback_rate_with_details, :parent => :chargeback_rate do
    after(:create) do |chargeback_rate|
      chargeback_rate.chargeback_rate_details << FactoryGirl.create(:chargeback_rate_detail_memory_used_with_tiers)
      chargeback_rate.chargeback_rate_details << FactoryGirl.create(:chargeback_rate_detail_memory_allocated_with_tiers)
    end
  end
end
