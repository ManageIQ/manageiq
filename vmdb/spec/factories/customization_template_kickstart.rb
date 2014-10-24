FactoryGirl.define do
  factory :customization_template_kickstart do
    sequence(:name)        { |n| "customization_template_kickstart_#{seq_padded_for_sorting(n)}" }
    sequence(:description) { |n| "Customization Template Kickstart #{seq_padded_for_sorting(n)}" }
    after(:build) do |x|
      x.pxe_image_type ||= FactoryGirl.create(:pxe_image_type)
    end
  end
end
