FactoryGirl.define do
  factory(:template_microsoft, :class => "TemplateMicrosoft", :parent => :template_infra) { vendor "microsoft" }
end
