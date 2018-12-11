FactoryBot.define do
  factory :container_group do
    sequence(:name) { |n| "container_group_#{seq_padded_for_sorting(n)}" }
  end

  factory :container_group_with_assoc, :parent => :container_group do
    association :ext_management_system, :factory => :ems_kubernetes
    association :container_project, :factory => :container_project
  end
end
