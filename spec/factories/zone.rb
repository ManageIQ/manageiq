FactoryBot.define do
  factory :zone do
    sequence(:name)        { |n| "Zone #{n}" }
    sequence(:description) { |n| "Zone #{n}" }
  end
end
