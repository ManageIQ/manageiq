RSpec.describe RemoteConsole::ClientAdapter::KubeExec do
  let(:container_project) { instance_double(ContainerProject, :name => "default") }

  let(:ems) { instance_double(ExtManagementSystem) }

  let(:container_group) do
    instance_double(
      ContainerGroup,
      :name                  => "nginx-pod",
      :container_project     => container_project,
      :ext_management_system => ems
    )
  end

  let(:container) do
    instance_double(
      Container,
      :name            => "nginx",
      :container_group => container_group
    )
  end

  let(:record) do
    instance_double(
      SystemConsole,
      :host_name => "127.0.0.1",
      :port      => 6443,
      :container => container
    )
  end

  subject { described_class.new(record, nil) }

  before do
    allow(ems).to receive(:authentication_token).with("bearer").and_return("token")

    ssl = instance_double(OpenSSL::SSL::SSLSocket)
    allow(OpenSSL::SSL::SSLSocket).to receive(:new).and_return(ssl)
    allow(OpenSSL::X509::Certificate).to receive(:new)
    allow(OpenSSL::PKey::RSA).to receive(:new)
    allow(File).to receive(:open)

    allow(ssl).to receive(:sync_close=)
    allow(ssl).to receive(:connect)

    driver = instance_double(WebSocket::Driver::Client)

    allow(WebSocket::Driver).to receive(:client).and_return(driver)
    allow(driver).to receive(:set_header)
    allow(driver).to receive(:start)
    allow(driver).to receive(:on)
  end

  describe "#path" do
    it "returns the kubernetes exec path" do
      expect(subject.send(:path))
        .to eq("/api/v1/namespaces/default/pods/nginx-pod/exec")
    end
  end

  describe "#query" do
    it "returns the kubernetes exec query" do
      expect(subject.send(:query)).to eq(
        "command=%2Fbin%2Fsh&container=nginx&stdin=true&stdout=true&stderr=true&tty=true"
      )
    end
  end
end
