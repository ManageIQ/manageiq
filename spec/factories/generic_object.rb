FactoryBot.define do
  factory :generic_object do
    sequence(:name) { |n| "generic_object_#{seq_padded_for_sorting(n)}" }
  end
end
