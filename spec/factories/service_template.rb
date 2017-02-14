FactoryGirl.define do
  factory :service_template do
  end

  factory :service_template_orchestration, :class => 'ServiceTemplateOrchestration', :parent => :service_template do
  end

  factory :service_template_ansible_playbook, :class => 'ServiceTemplateAnsiblePlaybook', :parent => :service_template
end
