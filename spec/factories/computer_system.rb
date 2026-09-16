FactoryBot.define do
  factory :computer_system do
    trait :with_hardware do
      hardware { create(:hardware) }
    end
  end
end
