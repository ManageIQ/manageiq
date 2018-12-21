FactoryBot.define do
  factory :service do
    sequence(:name) { |n| "service_#{seq_padded_for_sorting(n)}" }
  end

  factory :service_orchestration, :class => :ServiceOrchestration, :parent => :service
  factory :service_ansible_tower, :class => :ServiceAnsibleTower, :parent => :service
  factory :service_ansible_playbook, :class => :ServiceAnsiblePlaybook, :parent => :service
  factory :service_container_template, :class => :ServiceContainerTemplate, :parent => :service
end
