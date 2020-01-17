RSpec.describe OperatingSystem do
  context "#normalize_os_name" do
    {
      "an_amazing_undiscovered_os" => "unknown",
      "centos-7"                   => "linux_centos",
      "debian-8"                   => "linux_debian",
      "opensuse-13"                => "linux_suse",
      "sles-12"                    => "linux_suse",
      "rhel-7"                     => "linux_redhat",
      "ubuntu-15-10"               => "linux_ubuntu",
      "windows-2012-r2"            => "windows_generic",
      "vmnix-x86"                  => "linux_esx",
      "vista"                      => "windows_generic",
      "coreos-cloud"               => "linux_coreos",
    }.each do |image, expected|
      it "normalizes #{image}" do
        expect(described_class.normalize_os_name(image)).to eq(expected)
      end
    end
  end

  # passing in a vm or host
  context "#image_name" do
    it "uses os.distribution over os.product_type" do
      expect(
        described_class.image_name(host_with_os(:distribution => "rhel-7", :product_type => "centos-7"))
      ).to eq("linux_redhat")
    end

    it "falls back to os.product_type if invalid os.distribution" do
      expect(
        described_class.image_name(host_with_os(:distribution => "undiscovered-7", :product_type => "rhel-7"))
      ).to eq("linux_redhat")
    end

    it "falls back to os.product_name" do
      expect(
        described_class.image_name(host_with_os(:distribution => "undiscovered-7", :product_name => "rhel-7"))
      ).to eq("linux_redhat")
    end

    it "falls back to Host#user_assigned_os" do
      expect(
        described_class.image_name(host_with_os({:distribution => "undiscovered-7"}, {:user_assigned_os => "rhel-7"}))
      ).to eq("linux_redhat")
    end

    it "falls back to hardware.guest_os" do
      expect(
        described_class.image_name(host_with_os({:distribution => "undiscovered-7"}, {}, {:guest_os => "rhel-7"}))
      ).to eq("linux_redhat")
    end
  end

  def host_with_os(os_attributes = nil, host_attributes = nil, hardware_attributes = nil)
    host = Host.new(host_attributes || {})
    host.operating_system = OperatingSystem.new(os_attributes) if os_attributes
    host.hardware = Hardware.new(hardware_attributes) if hardware_attributes
    host
  end
end
