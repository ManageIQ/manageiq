describe OperatingSystem do
  context "#normalize_os_name" do
    {
      "an_amazing_undiscovered_os" => "unknown",
      "centos-7"                   => "linux_centos",
      "debian-8"                   => "linux_debian",
      "opensuse-13"                => "linux_suse",
      "sles-12"                    => "linux_suse",
      "rhel-7"                     => "linux_redhat",
      "ubuntu-15-10"               => "linux_ubuntu",
      "windows-2012-r2"            => "windows_generic"
    }.each do |image, expected|
      it "normalizes #{image}" do
        expect(described_class.normalize_os_name(image)).to eq(expected)
      end
    end
  end
end
