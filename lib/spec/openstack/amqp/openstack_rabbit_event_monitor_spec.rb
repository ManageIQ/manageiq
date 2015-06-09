require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. openstack})))
$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. openstack amqp})))
require 'openstack_rabbit_event_monitor'

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
    @options = @receiver_options.merge({:topics => @topics, :client_ip => "10.11.12.13"})
  end

  after do
    $log = @original_log
  end

  context "testing a connection" do
    before :each do
      @rabbit_connection = double
      OpenstackRabbitEventMonitor.stub(:connect).and_return(@rabbit_connection)
    end

    it "returns true on a successful test" do
      @rabbit_connection.should_receive(:start)
      @rabbit_connection.should_receive(:close)

      OpenstackRabbitEventMonitor.test_connection(@options).should be_true
    end

    it "returns false on an unsuccessful test" do
      @rabbit_connection.should_receive(:start).and_raise("Cannot connect to rabbit amqp")
      OpenstackRabbitEventMonitor.test_connection(@options).should be_false
    end
  end

  context "collecting events" do
    # At the moment, because of the asynchronous nature of rabbit, I don't have
    # a good way of spec'ing this out without pulling in something like
    # event_machine for driving some sort of asynchronous engine ... at least I
    # don't have (and haven't seen) any other decent ideas yet ... will have to
    # get back to this piece
  end

end
