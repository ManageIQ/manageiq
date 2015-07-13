FactoryGirl.define do
  factory :miq_event do
    sequence(:name)  { |num| "event_#{num}" }
    description      "Test Event"
  end
end
