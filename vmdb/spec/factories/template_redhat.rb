FactoryGirl.define do
  factory :template_redhat, :class => "TemplateRedhat", :parent => :template_infra do
    location { |x| "[storage] #{x.name}/#{x.name}.vmtx" }
    vendor   "redhat"
  end
end
