FactoryGirl.define do
  factory :configuration_script_source do
    sequence(:name) { |n| "configuration_script_source#{seq_padded_for_sorting(n)}" }
  end
end
