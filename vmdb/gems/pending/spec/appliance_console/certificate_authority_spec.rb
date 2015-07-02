require "spec_helper"
require "appliance_console/internal_database_configuration"
require "appliance_console/external_httpd_authentication"
require 'appliance_console/principal'
require 'appliance_console/certificate'
require "appliance_console/certificate_authority"

describe ApplianceConsole::CertificateAuthority do
  let(:host)  { "client.network.com" }
  let(:realm) { "NETWORK.COM" }
  subject { described_class.new(:ca_name => 'ipa', :hostname => host) }

  context "#status" do
    it "should have no status if no services called" do
      expect(subject.status_string).to eq("")
      expect(subject).to be_complete
    end

    it "should have status for waiting and complete services (not complete)" do
      subject.pgserver = :complete
      subject.pgclient = :waiting
      expect(subject).not_to be_complete
      expect(subject.status_string).to eq("pgclient: waiting pgserver: complete")
    end

    it "should be complete if all statuses are complete" do
      subject.pgserver = :complete
      expect(subject).to be_complete
      expect(subject.status_string).to eq("pgserver: complete")
    end

    it "should not be complete if any statuses have issues" do
      subject.pgserver = :complete
      subject.pgclient = :waiting
    end
  end

  context "#postgres server" do
    before do
      subject.pgserver = true
    end

    it "without ipa client should not install" do
      ipa_configured(false)
      expect { subject.activate }.to raise_error(ArgumentError, /ipa client/)
    end

    it "should install postgres server" do
      ipa_configured(true)
      expect_run(/getcert/, anything, response) # getcert returns: the certificate already exist

      ApplianceConsole::InternalDatabaseConfiguration.should_receive(:new)
        .and_return(double("config", :activate => true, :configure_postgres => true))
      LinuxAdmin::Service.should_receive(:new).and_return(double("Service", :restart => true))
      FileUtils.should_receive(:chmod).with(0644, anything)

      subject.should_receive(:say)
      subject.activate
      expect(subject.pgserver).to eq(:complete)
      expect(subject.status_string).to eq("pgserver: complete")
      expect(subject).to be_complete
    end

    it "should not change postgres if service not responding" do
      ipa_configured(true)
      expect_run(/getcert/, anything, response(3)) # getcert returns: waiting on the CA

      ApplianceConsole::InternalDatabaseConfiguration.should_not_receive(:new)
      LinuxAdmin::Service.should_not_receive(:new)
      subject.activate
      expect(subject.pgserver).to eq(:waiting)
      expect(subject.status_string).to eq("pgserver: waiting")
      expect(subject).not_to be_complete
    end
  end

  private

  def ipa_configured(ipa_client_installed)
    expect(ApplianceConsole::ExternalHttpdAuthentication).to receive(:ipa_client_configured?)
      .and_return(ipa_client_installed)
  end

  def expect_not_run(cmd = nil, params = anything)
    expect(AwesomeSpawn).not_to receive(:run).tap { |stmt| stmt.with(cmd, params) if cmd }
  end

  def expect_run(cmd, params, *responses)
    expectation = receive(:run).and_return(*(responses.empty? ? response : responses))
    if :none == params
      expectation.with(cmd)
    elsif params == anything || params == {}
      expectation.with(cmd, params)
    else
      expectation.with(cmd, :params => params)
    end
    expect(AwesomeSpawn).to(expectation)
  end

  def response(ret_code = 0)
    double("CommandResult", :success? => ret_code == 0, :failure? => ret_code != 0, :exit_status => ret_code)
  end
end
