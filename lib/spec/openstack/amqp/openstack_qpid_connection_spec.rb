require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. openstack})))
$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. openstack amqp})))
require 'openstack_qpid_connection'

describe OpenstackQpidConnection do

  before :each do
    @qsession = double("qpid session")
    @qconnection = double("qpid connection", :create_session => @qsession)

    OpenstackQpidConnection.stub(:available?).and_return(true)
    OpenstackQpidConnection.any_instance.stub(:create_connection).and_return(@qconnection)
    @connection = OpenstackQpidConnection.new(:hostname => "hostname", :port => 5672)
  end

  it "complains that host and port are not provided when they are not included in options" do
    @bad_connection = OpenstackQpidConnection.new
    expect { @bad_connection.open }.to raise_error
  end

  it "opens a connection to qpid" do
    @qconnection.should_receive(:open).and_return(nil)

    @connection.open
  end

  it "indicates that a connection is open when it is open" do
    @qconnection.should_receive(:open)
    @qconnection.should_receive(:open?).and_return(true)

    @connection.open
    @connection.open?.should be_true
  end

  it "indicates that a connection is not open when it is closed" do
    @connection.open?.should be_false
  end

  it "closes a connection to qpid" do
    @qconnection.should_receive(:open)
    @qconnection.should_receive(:open?).and_return(true)
    @qconnection.should_receive(:close)

    @connection.open
    @connection.close
  end

  it "creates a qpid session" do
    @qconnection.should_receive(:open)
    @qconnection.should_receive(:open?).and_return(true)
    @qconnection.should_receive(:create_session).and_return(@qsession)

    @connection.open
    @connection.session.should eq @qsession
  end
end
