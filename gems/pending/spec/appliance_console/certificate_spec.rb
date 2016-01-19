require "fileutils"
require "appliance_console/certificate"

describe ApplianceConsole::Certificate do
  before { expect(Open3).not_to receive(:capture) }
  let(:host)  { "client.network.com" }
  let(:realm) { "NETWORK.COM" }
  let(:service) { "postgres" }
  let(:key_filename) { "/tmp/certs/filename.key" }
  let(:cert_filename) { "/tmp/certs/filename.crt" }
  let(:root_filename) { "/tmp/certs/root.crt" }

  subject do
    described_class.new(:ca_name       => 'ipa',
                        :hostname      => host,
                        :service       => service,
                        :realm         => realm,
                        :cert_filename => cert_filename)
  end

  it "should set proper realm" do
    expect(subject.realm).to eq(realm)
  end

  # not sure if we care about this (it is probably allowing us to neglect )
  it "should have a principal" do
    expect(subject.principal.name).to eq("postgres/#{host}@#{realm}")
    expect(subject.principal).to be_ipa
  end

  it "should go through all if smooth sailing with chown" do
    subject.owner = "user.group"
    expect_getcert_status(response(1), response(0))
    expect_principal_register
    expect_request
    expect_chown
    expect_chmod([cert_filename])

    expect(subject.request).to be_complete
    expect(subject.status).to eq(:complete)
  end

  it "should try again if key was rejected - and not complete if rejected again" do
    subject.owner = "user.group"
    expect_getcert_status(response(2), response(2))
    expect_principal_register
    expect_request_again

    expect(subject.request).not_to be_complete
    expect(subject.status).to eq(:rejected)
  end

  it "should only run complete block if keys already exist" do
    expect_getcert_status(response)
    expect_chmod([cert_filename])
    yielded = false

    subject.request { yielded = true }
    expect(yielded).to eq(true)
    expect(subject).to be_complete
  end

  # private methods

  it "should create key filename from certificate name" do
    expect(subject.send(:key_filename)).to eq(key_filename)
  end

  it "should allow override of key filename" do
    subject = described_class.new(:cert_filename => cert_filename,
                                  :key_filename  => "other.key")
    expect(subject.send(:key_filename)).to eq("other.key")
  end

  private

  def expect_run(cmd, params, *responses)
    expect(AwesomeSpawn).to receive(:run).with(cmd, :params => params)
      .and_return(*(responses.empty? ? response : responses))
  end

  def expect_principal_register
    expect_run(/ipa/, anything)
  end

  def expect_request
    expect_run(/getcert/, hash_including(nil => "request"))
  end

  def expect_request_again
    expect_run(/getcert/, ["resubmit", "-w", "-f", cert_filename])
  end

  def expect_getcert_status(*responses)
    expect_run(/getcert/, ["status", "-f", cert_filename], *responses)
  end

  def expect_chmod(files)
    expect(FileUtils).to receive(:chmod).with(0644, files)
  end

  def expect_chown
    expect(FileUtils).to receive(:chown).with("user", "group", key_filename)
  end

  def response(ret_code = 0)
    AwesomeSpawn::CommandResult.new("cmd", "output", "", ret_code)
  end
end
