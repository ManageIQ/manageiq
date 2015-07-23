FactoryGirl.define do
  factory(:template_redhat, :class => "ManageIQ::Providers::Redhat::InfraManager::Template", :parent => :template_infra) { vendor "redhat" }
end
