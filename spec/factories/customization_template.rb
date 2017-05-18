FactoryGirl.define do
  factory :customization_template do
    sequence(:name)        { |n| "customization_template_#{seq_padded_for_sorting(n)}" }
    sequence(:description) { |n| "Customization Template #{seq_padded_for_sorting(n)}" }
    after(:build) do |x|
      x.pxe_image_type ||= FactoryGirl.create(:pxe_image_type)
    end
  end

  factory :customization_template_cloud_init do
    after(:build) do |x|
      x.pxe_image_type ||= FactoryGirl.create(:pxe_image_type)
    end
  end

  factory :customization_template_kickstart do
    sequence(:name)        { |n| "customization_template_kickstart_#{seq_padded_for_sorting(n)}" }
    sequence(:description) { |n| "Customization Template Kickstart #{seq_padded_for_sorting(n)}" }
    after(:build) do |x|
      x.pxe_image_type ||= FactoryGirl.create(:pxe_image_type)
    end
  end

  factory :customization_template_sysprep do
    sequence(:name)        { |n| "customization_template_syspre_#{seq_padded_for_sorting(n)}" }
    sequence(:description) { |n| "Customization Template Sysprep #{seq_padded_for_sorting(n)}" }
    after(:build) do |x|
      x.pxe_image_type ||= FactoryGirl.create(:pxe_image_type)
    end
  end
end
