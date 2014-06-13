require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. openstack})))
$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. openstack amqp})))
require 'openstack_event_monitor'
require 'openstack_qpid_event_monitor'
require 'openstack_rabbit_event_monitor'

describe OpenstackEventMonitor do
  before :each do
    @receivers = {"nova" => @nova_receiver, "glance" => @glance_receiver}
    @topics = {"nova" => "nova_topic", "glance" => "glance_topic"}
    @receiver_options = {:capacity => 1, :duration => 1}
    @options = @receiver_options.merge({:topics => @topics})
    @rabbit_host = {:hostname => "rabbit_host", :username => "rabbit_user", :password => "rabbit_pass"}
    @qpid_host = {:hostname => "qpid_host", :username => "qpid_user", :password => "qpid_pass"}
    @bad_host = {:hostname => "bad_host", :username => "bad_user", :password => "bad_pass"}

    OpenstackQpidConnection.stub(:available?).and_return(true)
  end

  it "selects rabbit when qpid is unavailable" do
    opts = @options.merge(@rabbit_host)
    OpenstackQpidEventMonitor.stub(:test_connection).with(opts).and_return(false)
    OpenstackRabbitEventMonitor.stub(:test_connection).with(opts).and_return(true)

    OpenstackEventMonitor.new(opts).class.should eq OpenstackRabbitEventMonitor
  end

  it "selects qpid when rabbit is unavailable" do
    opts = @options.merge(@qpid_host)
    OpenstackRabbitEventMonitor.stub(:test_connection).with(opts).and_return(false)
    OpenstackQpidEventMonitor.stub(:test_connection).with(opts).and_return(true)

    OpenstackEventMonitor.new(opts).class.should eq OpenstackQpidEventMonitor
  end

  it "selects null event monitor when nothing is available" do
    opts = @options.merge(@bad_host)
    OpenstackRabbitEventMonitor.stub(:test_connection).with(opts).and_return(false)
    OpenstackQpidEventMonitor.stub(:test_connection).with(opts).and_return(false)

    OpenstackEventMonitor.new(opts).class.should eq OpenstackNullEventMonitor
  end

  it "caches multiple event monitors for different keys" do
    # flipping the expectation for :available? in this test seemed to be
    # confusing should_receive, so swapped it out for stub instead
    qpid_options = @options.merge(@qpid_host)
    OpenstackRabbitEventMonitor.stub(:test_connection).with(qpid_options).and_return(false)
    OpenstackQpidEventMonitor.stub(:test_connection).with(qpid_options).and_return(true)
    qpid_instance = OpenstackEventMonitor.new(qpid_options)
    qpid_instance.class.should eq OpenstackQpidEventMonitor

    rabbit_options = @options.merge(@rabbit_host)
    OpenstackRabbitEventMonitor.stub(:test_connection).with(rabbit_options).and_return(true)
    OpenstackQpidEventMonitor.stub(:test_connection).with(rabbit_options).and_return(false)
    rabbit_instance = OpenstackEventMonitor.new(rabbit_options)
    rabbit_instance.class.should eq OpenstackRabbitEventMonitor

    # additionally, we should be able to access each event_monitor instance
    # directly from the parent event_monitor
    instance = OpenstackEventMonitor.new(qpid_options)
    instance.should eq qpid_instance

    instance = OpenstackEventMonitor.new(rabbit_options)
    instance.should eq rabbit_instance
  end
end
