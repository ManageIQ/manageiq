FactoryBot.define do
  factory :customization_template do
    sequence(:name)        { |n| "customization_template_#{seq_padded_for_sorting(n)}" }
    sequence(:description) { |n| "Customization Template #{seq_padded_for_sorting(n)}" }
    sequence(:script)      { |n| "script_name_#{seq_padded_for_sorting(n)}" }
    after(:build) do |x|
      x.pxe_image_type ||= FactoryBot.create(:pxe_image_type)
    end
  end

  factory :customization_template_cloud_init,
          :parent => :customization_template,
          :class  => "CustomizationTemplateCloudInit" do
    after(:build) do |x|
      x.pxe_image_type ||= FactoryBot.create(:pxe_image_type)
    end
  end

  factory :customization_template_kickstart,
          :parent => :customization_template,
          :class  => "CustomizationTemplateKickstart" do
    sequence(:name)        { |n| "customization_template_kickstart_#{seq_padded_for_sorting(n)}" }
    sequence(:description) { |n| "Customization Template Kickstart #{seq_padded_for_sorting(n)}" }
    after(:build) do |x|
      x.pxe_image_type ||= FactoryBot.create(:pxe_image_type)
    end
  end

  factory :customization_template_sysprep,
          :parent => :customization_template,
          :class  => "CustomizationTemplateSysprep" do
    sequence(:name)        { |n| "customization_template_sysprep_#{seq_padded_for_sorting(n)}" }
    sequence(:description) { |n| "Customization Template Sysprep #{seq_padded_for_sorting(n)}" }
    after(:build) do |x|
      x.pxe_image_type ||= FactoryBot.create(:pxe_image_type)
    end
  end
end
