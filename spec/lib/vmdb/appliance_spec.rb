require 'stringio'

RSpec.describe Vmdb::Appliance do
  describe "log_config" do
    context "logging settings" do
      let(:logger_io)     { StringIO.new }
      let(:secret_filter) { [] }
      let(:fake_settings) do
        {
          :authentication => {
            :username => "foobar",
            :password => "passw0rd",
            :ldaphost => "my_ldap_host",
          },
          :database => {
            :maintenance => {
              :reindex_schedule => "1 * * * *",
              :reindex_tables   => %w[Metric MiqQueue]
            }
          },
          :log => {
            :secret_filter => secret_filter
          }
        }
      end

      before do
        stub_settings(fake_settings)
        allow(Settings).to receive(:to_hash).and_return(fake_settings)
        described_class.log_config(:logger => ManageIQ::Loggers::Base.new(logger_io))
      end

      it "filters out secrets" do
        expect(logger_io.string).to include("password: [FILTERED]")
        expect(logger_io.string).to include("ldaphost: my_ldap_host")
      end

      context "with a user configured secret_filter" do
        let(:secret_filter) { ["ldaphost"] }

        it "will use user configured secret_filter" do
          expect(logger_io.string).to include("password: [FILTERED]")
          expect(logger_io.string).to include("ldaphost: [FILTERED]")
        end
      end
    end
  end

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
