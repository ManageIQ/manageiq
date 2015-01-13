FactoryGirl.define do
  factory :template_amazon, :class => "TemplateAmazon", :parent => :template_cloud do
    location { |x| "#{x.name}/#{x.name}.img.manifest.xml" }
    vendor   "amazon"
  end
end
