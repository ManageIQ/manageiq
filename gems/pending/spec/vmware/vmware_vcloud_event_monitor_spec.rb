require 'vmware/vmware_vcloud_event_monitor'

describe VmwareVcloudEventMonitor do
  before do
    @original_log = $log
    $log = double.as_null_object

    @topic = "vmware_vcloud_topic"
    @receiver_options = {:capacity => 1, :duration => 1}
    @options = @receiver_options.merge(:topics => @topic, :client_ip => "10.11.12.13")

    @rabbit_connection = double
    allow(VmwareVcloudEventMonitor).to receive(:connect).and_return(@rabbit_connection)
  end

  after do
    $log = @original_log
  end

  context "testing a connection" do
    it "returns true on a successful test" do
      expect(@rabbit_connection).to receive(:start)
      expect(@rabbit_connection).to receive(:close)

      expect(VmwareVcloudEventMonitor.test_connection(@options)).to be_truthy
    end

    it "raise exception on an unsuccessful test with bad credentials" do
      expect(@rabbit_connection).to receive(:start).and_raise(Bunny::AuthenticationFailureError.new('test', 'test', 5))
      expect(@rabbit_connection).to receive(:close)
      expect { VmwareVcloudEventMonitor.test_connection(@options) }.to(
        raise_error(MiqException::MiqInvalidCredentialsError)
      )
    end

    it "raise exception on an unsuccessful test with unreachable hostname" do
      expect(@rabbit_connection).to receive(:start).and_raise(Bunny::TCPConnectionFailedForAllHosts.new)
      expect(@rabbit_connection).to receive(:close)
      expect { VmwareVcloudEventMonitor.test_connection(@options) }.to raise_error(MiqException::MiqHostError)
    end

    it "raise exception on an unsuccessful test with unexpected exception" do
      expect(@rabbit_connection).to receive(:start).and_raise("Cannot connect to rabbit amqp")
      expect(@rabbit_connection).to receive(:close)
      expect { VmwareVcloudEventMonitor.test_connection(@options) }.to raise_error("Cannot connect to rabbit amqp")
    end
  end
end
