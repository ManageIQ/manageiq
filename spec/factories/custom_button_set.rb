FactoryGirl.define do
  factory :custom_button_set do
    sequence(:name)        { |n| "custom_button_set_#{seq_padded_for_sorting(n)}" }
    sequence(:description) { |n| "custom_button_set_#{seq_padded_for_sorting(n)}" }
  end
end
