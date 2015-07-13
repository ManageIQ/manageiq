FactoryGirl.define do
  factory :custom_button do
    sequence(:name)        { |n| "custom_button_#{seq_padded_for_sorting(n)}" }
    sequence(:description) { |n| "custom_button_#{seq_padded_for_sorting(n)}" }
  end
end
