FactoryGirl.define do
  factory :pxe_image do
    sequence(:name)         { |n| "pxe_image_#{n}" }
    sequence(:description)  { |n| "pxe_desc_#{n}"  }
    kernel                  'ubuntu-10.10-desktop-i386/vmlinuz'
    kernel_options          "vga=788 -- quiet"
  end

  factory :pxe_image_ipxe, :parent => :pxe_image, :class => :PxeImageIpxe do
  end

  factory :pxe_image_pxelinux, :parent => :pxe_image, :class => :PxeImagePxelinux do
  end
end
