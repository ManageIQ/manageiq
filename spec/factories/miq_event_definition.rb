FactoryBot.define do
  factory :miq_event_definition do
    sequence(:name)  { |num| "event_definition_#{num}" }
    description      { "Test event_definition" }
  end
end
