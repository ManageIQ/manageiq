FactoryBot.define do
  factory :pxe_image, :class => 'PxeImage' do
    sequence(:name)         { |n| "pxe_image_#{seq_padded_for_sorting(n)}" }
    sequence(:description)  { |n| "pxe_desc_#{seq_padded_for_sorting(n)}"  }
    kernel                  { 'ubuntu-10.10-desktop-i386/vmlinuz' }
    kernel_options          { "vga=788 -- quiet" }
  end

  factory :pxe_image_ipxe, :parent => :pxe_image, :class => 'PxeImageIpxe'
  factory :pxe_image_pxelinux, :parent => :pxe_image, :class => 'PxeImagePxelinux'
end
