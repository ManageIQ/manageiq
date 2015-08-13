FactoryGirl.define do
  factory :configured_system do
    sequence(:name) { |n| "Configured_system_#{seq_padded_for_sorting(n)}" }
  end
end
