FactoryGirl.define do
  factory :container_group do
    sequence(:name) { |n| "container_group_#{seq_padded_for_sorting(n)}" }
  end
end
