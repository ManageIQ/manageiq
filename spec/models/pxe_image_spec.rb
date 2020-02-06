RSpec.describe PxeImage do
  let(:image) { FactoryBot.create(:pxe_image) }

  context "#build_pxe_contents" do
    it "updates ks and ks_device options" do
      expected_output = "vga=788 -- quiet ks=http://1.1.1.1/ ksdevice=00:00:00:00:00:00"

      image.kernel_options += " ks=abc ksdevice="

      expect(image.build_pxe_contents(:ks       => "http://1.1.1.1/",
                                      :ksdevice => "00:00:00:00:00:00"))
        .to eq(expected_output)
    end

    it "appends ksdevice if missing" do
      expected_output = "vga=788 -- quiet ks=http://1.1.1.1/ ksdevice=00:00:00:00:00:00"

      image.kernel_options += " ks=abc"

      expect(image.build_pxe_contents(:ks       => "http://1.1.1.1/",
                                      :ksdevice => "00:00:00:00:00:00"))
        .to eq(expected_output)
    end

    it "appends ks if missing" do
      expected_output = "vga=788 -- quiet ksdevice=00:00:00:00:00:00 ks=http://1.1.1.1/"

      image.kernel_options += " ksdevice=abc"

      expect(image.build_pxe_contents(:ks       => "http://1.1.1.1/",
                                      :ksdevice => "00:00:00:00:00:00"))
        .to eq(expected_output)
    end

    it "removes ks and ksdevice if blank" do
      expected_output = "vga=788 -- quiet"

      expect(image.build_pxe_contents(:ks       => nil,
                                      :ksdevice => nil))
        .to eq(expected_output)
    end
  end
end
