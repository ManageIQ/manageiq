FactoryBot.define do
  factory :customization_spec do
    sequence(:name) { |n| "customization_spec_#{seq_padded_for_sorting(n)}" }
    typ { "Windows" }
    sequence(:description) { |n| "Customization spec #{seq_padded_for_sorting(n)}" }
    spec { { :options => {} } }
  end
end
