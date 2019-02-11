FactoryBot.define do
  factory :miq_policy do
    sequence(:name)        { |num| "policy_#{seq_padded_for_sorting(num)}" }
    sequence(:description) { |num| "Test Policy_#{seq_padded_for_sorting(num)}" }
    mode                   { 'control' }
    towhat                 { "Vm" }
  end

  factory :miq_policy_read_only, :parent => :miq_policy do
    read_only { true }
  end
end
