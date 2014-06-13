FactoryGirl.define do
  factory :windows_image do
    sequence(:name)         { |n| "windows_image_#{n}" }
    sequence(:description)  { |n| "windows_desc_#{n}"  }
  end

  factory :windows_image_ipxe, :parent => :windows_image, :class => :WindowsImageIpxe do
  end

  factory :windows_image_pxelinux, :parent => :windows_image, :class => :WindowsImagePxelinux do
  end
end
