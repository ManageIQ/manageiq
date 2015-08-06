FactoryGirl.define do
  factory(:template_openstack, :class => "ManageIQ::Providers::Openstack::CloudManager::Template", :parent => :template_cloud) { vendor "openstack" }
end
