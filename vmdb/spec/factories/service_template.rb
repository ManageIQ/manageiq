FactoryGirl.define do
  factory :service_template do
  end

  factory :service_template_orchestration, :class => :ServiceTemplateOrchestration, :parent => :service_template do
  end
end
