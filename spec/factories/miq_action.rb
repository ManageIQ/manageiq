FactoryBot.define do
  factory :miq_action do
    sequence(:name)        { |num| "action_#{seq_padded_for_sorting(num)}" }
    sequence(:description) { |num| "Test Action_#{seq_padded_for_sorting(num)}" }
    action_type            { "Test" }
  end
end
