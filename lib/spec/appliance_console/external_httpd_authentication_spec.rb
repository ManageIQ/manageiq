require "spec_helper"

require "active_support/all"
require "appliance_console/external_httpd_authentication"

describe ApplianceConsole::ExternalHttpdAuthentication do
  let(:host) { "this.server.com" }
  subject { described_class.new(host) }

  context "#domain_from_host" do
    it "should be blank for blank" do
      expect(subject.send(:domain_from_host, nil)).to be_blank
    end

    it "should be blank for non fqdn" do
      expect(subject.send(:domain_from_host, "hostonly")).to be_blank
    end

    it "should return first part" do
      expect(subject.send(:domain_from_host, "host.domain.com")).to eq("domain.com")
    end
  end

  context "#fqdn" do
    it "should handle blank values" do
      expect(subject.send(:fqdn, "host", nil)).to eq("host")
      expect(subject.send(:fqdn, nil, "domain.com")).to eq(nil)
    end

    it "should not append to a fqn" do
      expect(subject.send(:fqdn, "host.domain.com", "domain.com")).to eq("host.domain.com")
    end

    it "should append to a short host name" do
      expect(subject.send(:fqdn, "host", "domain.com")).to eq("host.domain.com")
    end
  end
end
