FactoryGirl.define do
  factory :custom_attribute do
  end

  factory :miq_custom_attribute, :parent => :custom_attribute do
    source   'EVM'
  end

  factory :ems_custom_attribute, :parent => :custom_attribute do
    source   'VC'
  end

  factory :kubernetes_label, :parent => :custom_attribute do
    source   'kubernetes'
    section  'labels'
  end
end
