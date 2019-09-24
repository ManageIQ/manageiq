FactoryBot.define do
  factory :custom_button_set do
    sequence(:name)        { |n| "custom_button_set_#{seq_padded_for_sorting(n)}" }
    sequence(:description) { |n| "custom_button_set_#{seq_padded_for_sorting(n)}" }

    transient do
      members { [] }
    end

    after(:create) do |custom_button_set, evaluator|
      custom_button_set.add_members(*evaluator.members)
    end
  end
end
