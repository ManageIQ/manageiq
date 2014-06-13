require "spec_helper"

describe PxeImageIpxe do
  let(:image) { FactoryGirl.create(:pxe_image_ipxe) }

  context "#build_pxe_contents" do
    it "updates ks and ks_device options" do
      expected_output = "#!ipxe\nkernel ubuntu-10.10-desktop-i386/vmlinuz vga=788 -- quiet ks=http://1.1.1.1/ ksdevice=00:00:00:00:00:00\ninitrd \nboot\n"

      image.kernel_options += " ks=abc ksdevice="

      expect(image.build_pxe_contents("http://1.1.1.1/", "00:00:00:00:00:00")).to eq(expected_output)
    end
  end
end
