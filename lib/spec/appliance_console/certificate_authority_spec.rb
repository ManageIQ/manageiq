require "spec_helper"
require "appliance_console/certificate_authority"

describe ApplianceConsole::CertificateAuthority do
  subject { described_class.new('localhost', '127.0.0.1') }

  context "with local ca" do
    before do
      subject.local('Red Hat')
    end

    it "should know is local" do
      expect(subject).to be_local
    end

    it "should create a ca" do
      AwesomeSpawn.should_receive(:run!).with(
        /so_ca.sh/,
        :params => {
          "-r" => ApplianceConsole::CertificateAuthority::CA_ROOT,
          "-C" => "/O=Red Hat"})
      FileUtils.stub(:rm)
      MiqPassword.stub(:generate_symmetric)

      subject.create
    end
  end

  context "with remote ca" do
    before do
      subject.remote('otherhost', 'user')
    end

    it "should know it is remote" do
      expect(subject).not_to be_local
    end
  end
end
