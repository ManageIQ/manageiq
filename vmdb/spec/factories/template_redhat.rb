FactoryGirl.define do
  factory(:template_redhat, :class => "TemplateRedhat", :parent => :template_infra) { vendor "redhat" }
end
