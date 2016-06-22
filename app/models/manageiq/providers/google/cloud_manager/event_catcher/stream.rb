# Helper class responsible for polling a Google Pubsub topic and retreiving
# event type messages. Parsing of the message is deferred to the caller of
# #poll.
class ManageIQ::Providers::Google::CloudManager::EventCatcher::Stream
  # Generic exception if we are unable to reach GCP
  class ProviderUnreachable < ManageIQ::Providers::BaseManager::EventCatcher::Runner::TemporaryFailure
  end

  # Topic wasn't found (event catcher likely not set up)
  class TopicNotFound < ManageIQ::Providers::BaseManager::EventCatcher::Runner::TemporaryFailure
  end

  def initialize(ems)
    @ems = ems
    @collecting_events = true
  end

  # Stop capturing events. Once stopped, event collection cannot be resumed.
  def stop
    @collecting_events = false
  end

  # Poll for events (blocks forever until #stop is called)
  def each_batch
    while @collecting_events
      yield events.map { |e| JSON.parse(e.message['data']) }
    end
  end

  private

  # Poll for messages. This makes a service call to the Google Pubsub service
  # and returns any messages generated from the activity log. Note that these
  # messages are acknowledged before returning, so the caller has no
  # responsibility to explicitly acknowledge them.
  #
  # @return [Array<Fog::Google::Pubsub::ReceivedMessage>] possibly empty list of messages
  def events
    # For now, return immediately with up to 10 messages
    @ems.with_provider_connection(:service => 'pubsub') do |google|
      subscription = get_or_create_subscription(google)
      subscription.pull(:return_immediately => true, :max_messages => 10).tap do |msgs|
        subscription.acknowledge(msgs)
      end
    end
  rescue Fog::Errors::Error
    raise ProviderUnreachable, "Error when contacting Google Pubsub for events; this may be a temporary failure."
  end

  def get_or_create_subscription(google)
    # If event catcher is not yet setup, then we'll get a fog error
    google.subscriptions.get(subscription_name) ||
      google.subscriptions.create(:name  => subscription_name,
                                  :topic => topic_name)
  rescue Fog::Errors::NotFound
    # Rather than expose the notfound error, we expose our own exception
    # indicating that the worker thread should back off
    msg = "Unable to find topic #{topic_name}; this likely is because event"\
        " support for the Google Cloud Platform is not yet setup. Please see"\
        " the documentation for instructions."
    raise TopicNotFound, msg
  end

  def subscription_name
    "projects/#{@ems.project}/subscriptions/manageiq-eventcatcher-#{@ems.guid}"
  end

  def topic_name
    "projects/#{@ems.project}/topics/manageiq-activity-log"
  end
end
