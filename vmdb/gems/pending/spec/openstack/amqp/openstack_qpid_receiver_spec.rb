require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. openstack})))
$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. openstack amqp})))
require 'openstack_qpid_receiver'
require 'openstack_amqp_event'

describe OpenstackQpidReceiver do

  it "gets notifications from qpid" do
    OpenstackQpidConnection.stub(:available?).and_return(true)

    qreceiver = double("qpid receiver")
    qsession = double("qpid session")

    qconnection = double("qpid connection")
    qconnection.stub(:hostname).and_return("10.10.10.10")
    qconnection.stub(:session).and_return(qsession)

    qsession.should_receive(:create_receiver).and_return(qreceiver)
    qreceiver.should_receive(:capacity=)

    qpid_messages = [
      qpid_message("message 1", "user1", 1, "content_type"),
      qpid_message("message 2", "user1", 1, "content_type"),
      qpid_message("message 3", "user1", 1, "content_type"),
    ]
    amqp_events = [
      amqp_event(qpid_messages[0]),
      amqp_event(qpid_messages[1]),
      amqp_event(qpid_messages[2]),
    ]
    qreceiver.stub(:available).and_return(3, 2, 1, 0)
    qreceiver.stub(:get).and_return(qpid_messages[0], qpid_messages[1], qpid_messages[2])

    receiver = OpenstackQpidReceiver.new(qconnection, "service", "exchange", "topic", "10.11.12.13")
    receiver.stub(:address).and_return("")
    receiver.stub(:duration).and_return(0)

    notifications = receiver.get_notifications
    notifications[0].payload.should eq qpid_messages[0].content
    notifications[1].payload.should eq qpid_messages[1].content
    notifications[2].payload.should eq qpid_messages[2].content
  end

  def qpid_message(content, user_id, priority, content_type)
    double("qpid_message", :content => content, :user_id => user_id, :priority => priority, :content_type => content_type)
  end

  def amqp_event(qpid_message)
    OpenstackAmqpEvent.new(qpid_message.content,
      :user_id => qpid_message.user_id,
      :priority => qpid_message.priority,
      :content_type => qpid_message.content_type
    )
  end
end
