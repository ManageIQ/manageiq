require 'openstack/events/openstack_rabbit_event_monitor'

describe OpenstackRabbitEventMonitor do
  before do
    @original_log = $log
    $log = double.as_null_object

    @nova_events = [{:name => "nova 1", :description => "first nova event"},
                    {:name => "nova 2", :description => "second nova event"}]
    @glance_events = [{:name => "glance 1", :description => "first glance event"},
                      {:name => "glance 2", :description => "second glance event"}]
    @all_events = @nova_events + @glance_events

    @topics = {"nova" => "nova_topic", "glance" => "glance_topic"}
    @receiver_options = {:capacity => 1, :duration => 1}
    @options = @receiver_options.merge(:topics => @topics, :client_ip => "10.11.12.13")

    @rabbit_connection = double
    allow(OpenstackRabbitEventMonitor).to receive(:connect).and_return(@rabbit_connection)
  end

  after do
    $log = @original_log
  end

  context "testing a connection" do
    it "returns true on a successful test" do
      expect(@rabbit_connection).to receive(:start)
      expect(@rabbit_connection).to receive(:close)

      expect(OpenstackRabbitEventMonitor.test_connection(@options)).to be_truthy
    end

    it "returns false on an unsuccessful test" do
      expect(@rabbit_connection).to receive(:start).and_raise("Cannot connect to rabbit amqp")
      expect(OpenstackRabbitEventMonitor.test_connection(@options)).to be_falsey
    end
  end

  context "collecting events" do
    # At the moment, because of the asynchronous nature of rabbit, I don't have
    # a good way of spec'ing this out without pulling in something like
    # event_machine for driving some sort of asynchronous engine ... at least I
    # don't have (and haven't seen) any other decent ideas yet ... will have to
    # get back to this piece
  end

  it "#remove_legacy_queues (private)" do
    @rabbit_channel = double
    allow(@rabbit_connection).to receive(:create_channel).and_return(@rabbit_channel)
    allow(@rabbit_channel).to receive(:close).and_return(nil)

    expect(@rabbit_connection).to receive(:queue_exists?).at_least(2).times.with(/^miq-/).and_return(true)
    expect(@rabbit_channel).to receive(:queue_delete).at_least(2).times.with(/^miq-/).and_return(nil)

    expect(@rabbit_connection).to receive(:queue_exists?).once.with("notifications.*").and_return(true)
    expect(@rabbit_channel).to receive(:queue_delete).once.with("notifications.*").and_return(nil)

    @event_monitor = OpenstackRabbitEventMonitor.new(@options)

    @event_monitor.send(:remove_legacy_queues)
  end
end
