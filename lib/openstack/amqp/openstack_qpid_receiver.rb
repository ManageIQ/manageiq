require_relative './openstack_amqp_event'
require_relative './openstack_qpid_connection'

#
# An AMQP Notification Receiver that uses Qpid to listen for messages.
#
class OpenstackQpidReceiver
  # Creates a new OpenstackQpidReceiver using the provided session,
  # exchange, subject, and options
  # e.g.,
  #     receiver = OpenstackQpidReceiver.new(session, "nova", "notifications.*")
  #
  # Options:
  # * :capacity: The total number of messages that can be held locally before
  # fetching more from the broker (default=50)
  # * :duration: The length of time (in seconds) the receiver should wait for a
  # message from the broker before timing out (default=10 seconds)
  def initialize(session, exchange, subject, options={})
    raise "qpid_messaging is not available" unless OpenstackQpidConnection.available?

    @options = {:capacity => 50, :duration => 10}
    @options.merge(options)

    @session = session
    @exchange = exchange
    @subject = subject
    @capacity = @options[:capacity]
    @duration_seconds = @options[:duration]

    @address_options = ADDRESS_OPTIONS % subject
  end

  # Checks with Openstack's qpid broker for messages and returns as many as
  # possible (up to <tt>max</tt>). Returns an empty array is no notifications
  # are flowing across the Openstack Notification bus.
  #
  # ==== Example
  #   receiver = OpenstackQpidReceiver.new(:hostname => "http://host.com")
  #   notifications = receiver.get_notifications
  #   notifications.each {|n| ... }
  def get_notifications(max=100)
    raise "Max messages must be greater than 0" if max < 1
    messages = []
    while receiver.available > 0 and messages.length < max
      begin
        msg = receiver.get(duration)
        messages << amqp_event(msg)
      rescue => e
        if e.to_s == "No message to fetch"
          # receiver throws a "No message to fetch" exception when
          # there are no more messages to grab ... this is truly
          # broken imo ... regardless, rescue and break b/c there's
          # no more messages to process for now
          break
        else
          raise
        end
      end
    end
    messages
  end

  private
  def amqp_event(event)
    OpenstackAmqpEvent.new(event.content,
      :user_id        => event.user_id,
      :priority       => event.priority,
      :content_type   => event.content_type,
    )
  end

  def duration # :nodoc:
    @duration ||= Qpid::Messaging::Duration.new(@duration_seconds * 1000)
  end

  ADDRESS_OPTIONS = <<EOD
{
  create: always,
  node: {
    type: topic,
    x-declare: {
      durable: true
    }
  },
}
EOD
  def address # :nodoc:
    unless @address
      address_details = "#{@exchange}/#{@subject} ; #{ADDRESS_OPTIONS}"
      @address = Qpid::Messaging::Address.new(address_details)
    end
    @address
  end

  def receiver # :nodoc:
    unless @receiver
      @receiver = @session.create_receiver(address)
      @receiver.capacity = @capacity
    end
    @receiver
  end
end
