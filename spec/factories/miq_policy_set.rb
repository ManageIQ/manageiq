FactoryGirl.define do
  factory :miq_policy_set do
    sequence(:description) { |num| "Test Policy Set_#{seq_padded_for_sorting(num)}" }
  end
end
