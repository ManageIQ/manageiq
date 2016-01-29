#
# Uses the AWS Config service to monitor for events.
#
# AWS Config events are collected in an SNS Topic.  Each appliance uses a unique
# SQS queue subscribed to the AWS Config topic.  If the appliance-specific queue
# doesn't exist, this event monitor will create the queue and subscribe the
# queue to the AWS Config topic.
#
class ManageIQ::Providers::Amazon::CloudManager::EventCatcher::Stream
  class ProviderUnreachable < ManageIQ::Providers::BaseManager::EventCatcher::Runner::TemporaryFailure
  end

  #
  # Creates an event monitor
  #
  # @param [ManageIQ::Providers::Amazon::CloudManager] ems
  # @param [String] sns_aws_config_topic_name
  AWS_CONFIG_TOPIC = "AWSConfig_topic"
  def initialize(ems, sns_aws_config_topic_name = AWS_CONFIG_TOPIC)
    @ems               = ems
    @topic_name        = sns_aws_config_topic_name
    @collecting_events = false
  end

  #
  # Start capturing events
  #
  def start
    @collecting_events = true
  end

  #
  # Stop capturing events
  #
  def stop
    @collecting_events = false
  end

  #
  # Collect events off the appliance-specific queue and return the events as a
  # batch to the caller.
  #
  # :yield: array of Amazon events as hashes
  #
  def each_batch
    while @collecting_events
      # allow the queue to be lazy created
      # if the amazon account doesn't have AWS Config enabled yet, this will pick
      # up if AWS Config is enabled later
      queue_url ||= find_or_create_queue
      yield collect_events(queue_url) if queue_url
    end
  end

  #
  # Similar to #each_batch, but yields each event individually.
  #
  # :yield: an Amazon event as a hash
  #
  def each
    each_batch do |events|
      events.each { |e| yield e }
    end
  end

  #
  # Find the appliance-specific queue, or create the appliance-specific queue
  # and subscribe it to the AWS Config topic.
  #
  # @return [String] is a queue_url
  def find_or_create_queue
    log_header = "MIQ(#{self.class.name}##{__method__})"
    queue_name = "manageiq-awsconfig-queue-#{@ems.guid}"

    begin
      $aws_log.debug("#{log_header} Looking for Amazon SQS Queue #{queue_name} ...")
      queue_url = sqs_get_queue_url(queue_name)
      $aws_log.debug("#{log_header} ... found Amazon SQS Queue")
      queue_url
    rescue Aws::SQS::Errors::NonExistentQueue
      sns_topic = find_sns_topic(@topic_name)
      if sns_topic
        $aws_log.info("#{log_header} Amazone SQS Queue #{queue_name} does not exist; creating queue")
        queue_url = sqs_create_queue(queue_name)
        $aws_log.info("#{log_header} Subscribing Queue #{queue_name} to AWSConfig_topic")
        subscribe_topic_to_queue(sns_topic, queue_url)
        $aws_log.info("#{log_header} Created Amazon SQS Queue #{queue_name} and subscribed to AWSConfig_topic")
        queue_url
      else
        $aws_log.warn("#{log_header} Unable to find the AWS Config Topic '#{@topic_name}'. " \
                      "Cannot collect Amazon events for AWS Access Key ID #{@ems.authentication_userid}")
        $aws_log.warn("#{log_header} Contact Amazon to create the AWS Config service and topic for Amazon events.")
        raise ProviderUnreachable.new("Unable to find the AWS Config Topic '#{@topic_name}'")
      end
    rescue Aws::SQS::Errors::ServiceError => exception
      raise ProviderUnreachable.new(exception.message)
    end
  end

  private

  def sqs_create_queue(queue_name)
    @ems.sqs.client.create_queue(:queue_name => queue_name).queue_url
  end

  def sqs_get_queue_url(queue_name)
    @ems.sqs.client.get_queue_url(:queue_name => queue_name).queue_url
  end

  # @return [Aws::SNS::Topic] the found topic or nil
  def find_sns_topic(topic_name)
    @ems.sns.topics.detect { |t| t.arn.split(/:/)[-1] == topic_name }
  end

  # @param [Aws::SNS::Topic] aws_config_topic
  # @param [String] queue_url
  def subscribe_topic_to_queue(aws_config_topic, queue_url)
    # the old behavior also added a policy to the queue to allow the topic
    # to send the queue messages - not sure if this is wanted...
    # https://github.com/aws/aws-sdk-ruby/blob/74ba5e/lib/aws/sns/topic.rb#L86-L90
    # https://github.com/aws/aws-sdk-ruby/blob/74ba5e/lib/aws/sns/topic.rb#L368-L378
    queue_arn = queue_url_to_arn(queue_url)
    subscription = aws_config_topic.subscribe(:protocol => 'sqs', :endpoint => queue_arn)
    raise ProviderUnreachable.new("Can't subscribe to #{queue_arn}") unless subscription.arn.present?
  end

  def queue_url_to_arn(queue_url)
    arn_attribute = "QueueArn"
    @ems.sqs.client.get_queue_attributes(
      :queue_url       => queue_url,
      :attribute_names => [arn_attribute]
    ).attributes[arn_attribute]
  end

  def collect_events(queue_url)
    events = []
    queue_poller = Aws::SQS::QueuePoller.new(queue_url, :client => @ems.sqs.client)
    queue_poller.poll(:idle_timeout => 5) do |sqs_message|
      event = parse_event(sqs_message)
      events << event if event
    end
    events
  end

  # @param [Aws::SQS::Types::Message] message
  def parse_event(message)
    log_header = "MIQ(#{self.class.name}##{__method__})"
    event = JSON.parse(JSON.parse(message.body)['Message'])
    message_type = event["messageType"]
    $log.info("#{log_header} Found SNS Message with message type #{message_type}")
    return unless message_type == "ConfigurationItemChangeNotification"

    log_header = "MIQ(#{self.class.name}##{__method__})"
    event["messageId"] = message.message_id
    event["eventType"] = parse_event_type(event)
    $log.info("#{log_header} Parsed event from SNS Message #{event["eventType"]}")
    event
  end

  def parse_event_type(event)
    event_type_prefix = event.fetch_path("configurationItem", "resourceType")
    change_type       = event.fetch_path("configurationItemDiff", "changeType")

    if event_type_prefix.end_with?("::Instance")
      suffix   = change_type if change_type == "CREATE"
      suffix ||= parse_instance_state_change(event)
    else
      suffix = change_type
    end

    # e.g., AWS_EC2_Instance_STARTED
    "#{event_type_prefix}_#{suffix}".gsub("::", "_")
  end

  def parse_instance_state_change(event)
    change_type = event["configurationItemDiff"]["changeType"]
    return change_type if change_type == "CREATE"

    state_changed = event.fetch_path("configurationItemDiff", "changedProperties", "Configuration.State.Name")
    state_changed ? state_changed["updatedValue"] : change_type
  end
end
