FactoryGirl.define do
  factory(:template_microsoft, :class => "ManageIQ::Providers::Microsoft::InfraManager::Template", :parent => :template_infra) { vendor "microsoft" }
end
