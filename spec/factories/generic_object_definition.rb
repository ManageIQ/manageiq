FactoryGirl.define do
  factory :generic_object_definition do
    sequence(:name) { |n| "generic_object_definition_#{seq_padded_for_sorting(n)}" }
  end
end
