FactoryBot.define do
  factory :compliance do
    sequence(:id)          { |n| 10_000_000 + n }
    sequence(:resource_id) { |n| 10_000_010 + n }
    resource_type          { 'Host' }
    compliant              { true }
    timestamp              { DateTime.current }
    updated_on             { DateTime.current }
    event_type             { 'string' }
    compliance_details     { [] }

    trait :with_details_and_conditions do
      after(:create) do |x|
        FactoryBot.create(:compliance_detail,
                          :condition => FactoryBot.create(:condition),
                          :compliance => x
        )
        FactoryBot.create(:compliance_detail,
                          :condition => FactoryBot.create(:condition),
                          :compliance => x
        )
      end
    end

  end
end
