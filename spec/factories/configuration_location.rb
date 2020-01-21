FactoryBot.define do
  factory :configuration_location do
    sequence(:name) { |n| "configuration_location#{seq_padded_for_sorting(n)}" }
  end
end
