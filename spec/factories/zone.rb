FactoryGirl.define do
  factory :zone do
    sequence(:name)        { |n| Zone.exists? ? "Zone #{n}" : "default" }
    sequence(:description) { |n| Zone.exists? ? "Zone #{n}" : "Default Zone" }
  end
end
