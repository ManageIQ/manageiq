require 'stringio'

RSpec.describe Vmdb::Appliance do
  describe ".installed_rpms (private)" do
    it "writes the correct string" do
      file = StringIO.new
      rpms = {
        "one"   => "v1",
        "two"   => "v2",
        "three" => "v3",
        "aaaa"  => "va"
      }
      out = "aaaa va\none v1\nthree v3\ntwo v2"
      path = Pathname.new("/var/www/miq/vmdb/log/package_list_rpm.txt")

      expect(File).to receive(:open).with(path, "a").and_yield(file)
      expect(LinuxAdmin::Rpm).to receive(:list_installed).and_return(rpms)
      described_class.send(:installed_rpms)
      file.rewind
      expect(file.read).to include(out)
    end
  end
end
