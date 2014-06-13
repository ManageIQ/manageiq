FactoryGirl.define do
  factory :lan do
    sequence(:name) { |n| "Lan #{n}" }
  end
end
