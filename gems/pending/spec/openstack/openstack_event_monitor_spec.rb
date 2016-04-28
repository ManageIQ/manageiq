require 'openstack/openstack_event_monitor'
require 'openstack/events/openstack_rabbit_event_monitor'

describe OpenstackEventMonitor do
  before :each do
    @receivers = {"nova" => @nova_receiver, "glance" => @glance_receiver}
    @topics = {"nova" => "nova_topic", "glance" => "glance_topic"}
    @receiver_options = {:capacity => 1, :duration => 1}
    @options = @receiver_options.merge(:topics => @topics)
    @rabbit_host = {:hostname => "rabbit_host", :username => "rabbit_user", :password => "rabbit_pass",
                    :events_monitor => :amqp}
    @bad_host = {:hostname => "bad_host", :username => "bad_user", :password => "bad_pass"}
  end

  it "selects null event monitor when nothing is available" do
    opts = @options.merge(@bad_host)
    allow(OpenstackRabbitEventMonitor).to receive(:test_connection).with(opts).and_return(false)

    expect(OpenstackEventMonitor.new(opts).class).to eq OpenstackNullEventMonitor
  end

  it "orders the event monitor plugins correctly" do
    plugins = OpenstackEventMonitor.subclasses

    expect(plugins.first).to eq OpenstackRabbitEventMonitor
    expect(plugins.last).to eq OpenstackNullEventMonitor
  end
end
