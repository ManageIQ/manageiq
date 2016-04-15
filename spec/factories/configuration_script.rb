FactoryGirl.define do
  factory :configuration_script do
    sequence(:name) { |n| "Configuration_script_#{seq_padded_for_sorting(n)}" }
    sequence(:manager_ref) { SecureRandom.random_number(100) }
    variables :instance_ids => ['i-3434']
  end
end
