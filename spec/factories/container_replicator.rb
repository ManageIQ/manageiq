FactoryBot.define do
  factory :container_replicator do
    sequence(:name) { |n| "container_replicator_#{seq_padded_for_sorting(n)}" }
  end

  factory :replicator_with_assoc, :parent => :container_replicator do
    association :ext_management_system, :factory => :ems_kubernetes
    association :container_project, :factory => :container_project
  end
end
