FactoryGirl.define do
  factory(:template_openstack, :class => "TemplateOpenstack", :parent => :template_cloud) { vendor "openstack" }
end
