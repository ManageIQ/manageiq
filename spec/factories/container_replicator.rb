FactoryGirl.define do
  factory :container_replicator do
    sequence(:name) { |n| "container_replicator_#{seq_padded_for_sorting(n)}" }
  end
end
