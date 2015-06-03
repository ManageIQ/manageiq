require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. openstack})))
$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. openstack amqp})))
require 'openstack_qpid_event_monitor'
require 'openstack_qpid_connection'
require 'openstack_qpid_receiver'

describe OpenstackQpidEventMonitor do
  before do
    @original_log = $log
    $log = double.as_null_object

    @qpid_session = double("qpid session")

    @nova_events = [{:name => "nova 1", :description => "first nova event"},
               {:name => "nova 2", :description => "second nova event"}]
    @glance_events = [{:name => "glance 1", :description => "first glance event"},
               {:name => "glance 2", :description => "second glance event"}]
    @all_events = @nova_events + @glance_events

    @notification_connection = double("notification_connection", :open => nil, :close => nil)
    @notification_connection.stub(:session).and_return(@qpid_session)
    @notification_connection.stub(:hostname).and_return("10.10.10.10")

    @nova_receiver = double("nova_receiver",
       :get_notifications => @nova_events,
       :exchange_name     => "nova")
    @glance_receiver = double("glance_receiver",
       :get_notifications => @glance_events,
       :exchange_name     => "glance")

    @receivers = {"nova" => @nova_receiver, "glance" => @glance_receiver}
    @topics = {"nova" => "nova_topic", "glance" => "glance_topic"}
    @receiver_options = {:capacity => 1, :duration => 1}
    @options = @receiver_options.merge({:topics => @topics, :client_ip => "10.11.12.13"})

    @monitor = OpenstackQpidEventMonitor.new(@options)
    @monitor.stub(:create_connection).and_return(@notification_connection)
    @monitor.stub(:create_receiver) { |exchange, topic, options| @receivers[exchange] }
  end

  after do
    $log = @original_log
  end

  it "initializes receivers based on given topics" do
    @monitor.should_receive(:create_v1_receiver).with("nova", "nova_topic").and_return(@nova_receiver)
    @monitor.should_receive(:create_v2_receiver).with("nova", "nova_topic").and_return(@nova_receiver)
    @monitor.should_receive(:create_v1_receiver).with("glance", "glance_topic").and_return(@glance_receiver)
    @monitor.should_receive(:create_v2_receiver).with("glance", "glance_topic").and_return(@glance_receiver)
    @monitor.start
    @monitor.each_batch { @monitor.stop }
  end

  it "responds with an iterable object from each_batch" do
    @monitor.each_batch do |events|
      events.should match_array @all_events
    end
  end

  it "can iterate events with each" do
    names = @all_events.map {|e| e[:name]}
    @monitor.each do |event|
      names.should include(event[:name])
    end
  end

  it "opens the connection on start and closes the connection on stop" do
    @notification_connection.should_receive(:open)
    @notification_connection.should_receive(:close)

    @monitor.start
    @monitor.stop
  end
end
