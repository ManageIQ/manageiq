FactoryGirl.define do
  factory :customization_template_cloud_init do
    after(:build) do |x|
      x.pxe_image_type ||= FactoryGirl.create(:pxe_image_type)
    end
  end
end
