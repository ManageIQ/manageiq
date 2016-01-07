require "spec_helper"
require "appliance_console/principal"

describe ApplianceConsole::Principal do
  before { expect(Open3).not_to receive(:capture3) }
  let(:hostname) { "machine.network.com" }
  let(:realm)    { "NETWORK.COM" }
  let(:service)  { "postgres" }
  let(:principal_name) { "postgres/machine.network.com@NETWORK.COM" }

  subject { described_class.new(:hostname => hostname, :realm => realm, :service => service) }

  it { expect(subject.hostname).to eq(hostname) }
  it { expect(subject.realm).to eq(realm) }
  it { expect(subject.service).to eq(service) }

  it { expect(subject.name).to eq(principal_name) }
  it { expect(subject.subject_name).to match(/CN=#{hostname}.*O=#{realm}/) }
  it { expect(subject).to be_ipa }

  it "should register if not yet registered" do
    expect_run(/ipa/, ["service-find", "--principal", principal_name], response(1))
    expect_run(/ipa/, ["service-add", "--force", principal_name], response)

    subject.register
  end

  it "should not register if already registered" do
    expect_run(/ipa/, ["service-find", "--principal", principal_name], response)

    subject.register
  end

  it "should not register if not ipa" do
    subject.ca_name = "other"
    subject.register
  end

  private

  def expect_run(cmd, params, *responses)
    expect(AwesomeSpawn).to receive(:run).with(cmd, :params => params)
      .and_return(*(responses.empty? ? response : responses))
  end

  def response(ret_code = 0)
    AwesomeSpawn::CommandResult.new("cmd", "output", "", ret_code)
  end
end
