FactoryBot.define do
  factory :system_service do
    sequence(:name) { |n| "system_service_#{seq_padded_for_sorting(n)}" }
  end
end
