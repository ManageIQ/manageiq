RSpec.describe PxeImagePxelinux do
  let(:image) { FactoryBot.create(:pxe_image_pxelinux) }

  context "#build_pxe_contents" do
    it "updates ks and ks_device options" do
      expected_output = <<~PXE_MENU
        timeout 0
        default #{image.name}

        label #{image.name}
           menu label #{image.description}
           kernel ubuntu-10.10-desktop-i386/vmlinuz
           append vga=788 -- quiet ks=http://1.1.1.1/ ksdevice=00:00:00:00:00:00

      PXE_MENU

      image.kernel_options += " ks=abc ksdevice="

      expect(image.build_pxe_contents(:ks       => "http://1.1.1.1/",
                                      :ksdevice => "00:00:00:00:00:00"))
        .to eq(expected_output)
    end
  end
end
