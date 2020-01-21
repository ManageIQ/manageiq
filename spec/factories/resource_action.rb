FactoryBot.define do
  factory :resource_action do
    trait :with_dialog do
      dialog
    end
  end
end
