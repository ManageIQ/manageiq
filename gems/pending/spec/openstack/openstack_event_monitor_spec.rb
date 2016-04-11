require 'openstack/openstack_event_monitor'
require 'openstack/events/openstack_rabbit_event_monitor'

describe OpenstackEventMonitor do
  before :each do
    @receivers = {"nova" => @nova_receiver, "glance" => @glance_receiver}
    @topics = {"nova" => "nova_topic", "glance" => "glance_topic"}
    @receiver_options = {:capacity => 1, :duration => 1}
    @options = @receiver_options.merge(:topics => @topics)
    @rabbit_host = {:hostname => "rabbit_host", :username => "rabbit_user", :password => "rabbit_pass"}
    @bad_host = {:hostname => "bad_host", :username => "bad_user", :password => "bad_pass"}
  end

  it "selects null event monitor when nothing is available" do
    opts = @options.merge(@bad_host)
    allow(OpenstackRabbitEventMonitor).to receive(:test_connection).with(opts).and_return(false)

    expect(OpenstackEventMonitor.new(opts).class).to eq OpenstackNullEventMonitor
  end

  it "caches multiple event monitors for different keys" do
    rabbit_options = @options.merge(@rabbit_host)
    allow(OpenstackRabbitEventMonitor).to receive(:test_connection).with(rabbit_options).and_return(true)
    rabbit_instance = OpenstackEventMonitor.new(rabbit_options)
    expect(rabbit_instance.class).to eq OpenstackRabbitEventMonitor

    # additionally, we should be able to access the event_monitor instance
    # directly from the parent event_monitor
    instance = OpenstackEventMonitor.new(rabbit_options)
    expect(instance).to eq rabbit_instance
  end

  it "orders the event monitor plugins correctly" do
    plugins = OpenstackEventMonitor.subclasses

    expect(plugins.first).to eq OpenstackRabbitEventMonitor
    expect(plugins.last).to eq OpenstackNullEventMonitor
  end
end
