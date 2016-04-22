FactoryGirl.define do
  factory :compliance do
    sequence(:id)          { |n| 10000000 + n }
    sequence(:resource_id) { |n| 10000010 + n }
    resource_type          'Host'
    compliant              true
    timestamp              DateTime.now
    updated_on             DateTime.now
    event_type             'string'
    compliance_details     []
  end
end