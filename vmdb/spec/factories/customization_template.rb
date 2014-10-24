FactoryGirl.define do
  factory :customization_template do
    sequence(:name)        { |n| "customization_template_#{seq_padded_for_sorting(n)}" }
    sequence(:description) { |n| "Customization Template #{seq_padded_for_sorting(n)}" }
    after(:build) do |x|
      x.pxe_image_type ||= FactoryGirl.create(:pxe_image_type)
    end
  end
end
