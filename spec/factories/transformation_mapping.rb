FactoryGirl.define do
  factory :transformation_mapping do
    sequence(:name) { |n| "Transformation Mapping #{seq_padded_for_sorting(n)}" }
  end
end
