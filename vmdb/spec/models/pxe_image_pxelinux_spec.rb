require "spec_helper"

describe PxeImagePxelinux do
  let(:image) { FactoryGirl.create(:pxe_image_pxelinux) }

  context "#build_pxe_contents" do
    it "updates ks and ks_device options" do
      expected_output = "timeout 0\ndefault #{image.name}\n\nlabel #{image.name}\n   menu label #{image.description}\n   kernel ubuntu-10.10-desktop-i386/vmlinuz\n   append vga=788 -- quiet ks=http://1.1.1.1/ ksdevice=00:00:00:00:00:00\n\n"

      image.kernel_options += " ks=abc ksdevice="

      expect(image.build_pxe_contents("http://1.1.1.1/", "00:00:00:00:00:00")).to eq(expected_output)
    end
  end
end
