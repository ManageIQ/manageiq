FactoryGirl.define do
  factory(:template_google, :class => "ManageIQ::Providers::Google::CloudManager::Template", :parent => :template_cloud) { vendor "google" }
end
