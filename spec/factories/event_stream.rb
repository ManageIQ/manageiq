FactoryGirl.define do
  factory :event_stream do
    sequence(:id) { SecureRandom.random_number(100) }
    event_type      "TestEntry"
    source          "TestSource"
  end
end
