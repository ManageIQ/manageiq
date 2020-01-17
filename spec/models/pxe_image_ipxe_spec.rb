RSpec.describe PxeImageIpxe do
  let(:image) { FactoryBot.create(:pxe_image_ipxe) }

  context "#build_pxe_contents" do
    it "updates ks and ks_device options" do
      expected_output = <<~PXE_SCRIPT
        #!ipxe
        kernel ubuntu-10.10-desktop-i386/vmlinuz vga=788 -- quiet ks=http://1.1.1.1/ ksdevice=00:00:00:00:00:00
        boot
      PXE_SCRIPT

      image.kernel_options += " ks=abc ksdevice="

      expect(image.build_pxe_contents(:ks       => "http://1.1.1.1/",
                                      :ksdevice => "00:00:00:00:00:00"))
        .to eq(expected_output)
    end

    it "inserts initrd option if present" do
      expected_output = <<~PXE_SCRIPT
        #!ipxe
        kernel ubuntu-10.10-desktop-i386/vmlinuz vga=788 -- quiet ks=http://1.2.3.4/ ksdevice=12:34:56:78:90:ab
        initrd /path/to/init.rd
        boot
      PXE_SCRIPT

      image.initrd = "/path/to/init.rd"

      expect(image.build_pxe_contents(:ks       => "http://1.2.3.4/",
                                      :ksdevice => "12:34:56:78:90:ab"))
        .to eq(expected_output)
    end
  end
end
