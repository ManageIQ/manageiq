FactoryGirl.define do
  factory :customization_template do
    sequence(:name)        { |n| "customization_template_#{n}" }
    sequence(:description) { |n| "Customization Template #{n}" }
    after(:build) do |x|
      x.pxe_image_type ||= FactoryGirl.create(:pxe_image_type)
    end
  end
end
