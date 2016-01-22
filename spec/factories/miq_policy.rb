FactoryGirl.define do
  factory :miq_policy do
    sequence(:name)        { |num| "policy_#{seq_padded_for_sorting(num)}" }
    sequence(:description) { |num| "Test Policy_#{seq_padded_for_sorting(num)}" }
    towhat                 "Vm"
  end
end
