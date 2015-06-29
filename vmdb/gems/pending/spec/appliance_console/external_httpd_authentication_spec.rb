require "spec_helper"

require "active_support/all"
require "appliance_console/external_httpd_authentication"
require "appliance_console/prompts"

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

  context "#ask_for_parameters" do
    context "with just hostname" do
      subject do
        Class.new(described_class) do
          include ApplianceConsole::Prompts
        end.new(host)
      end
      it "supports just host (appliance_console use case)" do
        expect(subject).to receive(:say).with(/ipa/i)
        expect(subject).to receive(:just_ask).with(/hostname/i, nil, anything, anything).and_return("ipa")
        expect(subject).to receive(:just_ask).with(/domain/i, "server.com", anything, anything).and_return("server.com")
        expect(subject).to receive(:just_ask).with(/realm/i, "SERVER.COM").and_return("realm.server.com")
        expect(subject).to receive(:just_ask).with(/principal/i, "admin").and_return("admin")
        expect(subject).to receive(:just_ask).with(/password/i, nil).and_return("password")
        expect(subject.ask_for_parameters).to be_true
        expect(subject.send(:realm)).to eq("REALM.SERVER.COM")
        # expect(subject.ipaserver).to eq("ipa.server.com")
      end
    end
  end
end
