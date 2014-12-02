require 'Amazon/amazon_connection'

#
# Uses the AWS Config service to monitor for events.
#
# AWS Config events are collected in an SNS Topic.  Each appliance uses a unique
# SQS queue subscribed to the AWS Config topic.  If the appliance-specific queue
# doesn't exist, this event monitor will create the queue and subscribe the
# queue to the AWS Config topic.
#
class AmazonEventMonitor
  #
  # Creates an AmazonEventMonitor
  #
  def initialize(aws_access_key_id, aws_secret_access_key, aws_region, queue_id, sns_aws_config_topic_name = "AWSConfig_topic")
    @aws_access_key_id     = aws_access_key_id
    @aws_secret_access_key = aws_secret_access_key
    @aws_region            = aws_region
    @queue_id              = queue_id
    @topic_name            = sns_aws_config_topic_name
    @collecting_events     = false
    @queue                 = nil
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
      @queue ||= find_or_create_queue
      yield collect_events(@queue) if @queue
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

  private

  #
  # Find the appliance-specific queue, or create the appliance-specific queue
  # and subscribe it to the AWS Config topic.
  #
  def find_or_create_queue
    log_header = "MIQ(#{self.class.name}##{__method__})"

    # manageiq-awsconfig-queue-queue_id
    queue_name = "manageiq-awsconfig-queue-#{@queue_id}"

    begin
      $aws_log.debug("#{log_header} Looking for Amazon SQS Queue #{queue_name} ...")
      queue = sqs.queues.named(queue_name)
      $aws_log.debug("#{log_header} ... found Amazon SQS Queue")
    rescue AWS::SQS::Errors::NonExistentQueue
      aws_config_topic = find_aws_config_topic
      if aws_config_topic
        $aws_log.info("#{log_header} Amazone SQS Queue #{queue_name} does not exist; creating queue")
        queue = sqs.queues.create(queue_name)

        $aws_log.info("#{log_header} Subscribing Queue #{queue_name} to AWSConfig_topic")
        aws_config_topic.subscribe(queue)
        $aws_log.info("#{log_header} Created Amazon SQS Queue #{queue_name} and subscribed to AWSConfig_topic")
      else
        $aws_log.warn("#{log_header} Unable to find the AWS Config Topic. " \
                      "Cannot collect Amazon events for AWS Access Key ID #{@aws_access_key_id}")
        $aws_log.warn("#{log_header} Contact Amazon to create the AWS Config service and topic for Amazon events.")
        queue = nil
        # no need to raise an error
      end
    end
    queue
  end

  def find_aws_config_topic
    sns.topics.detect { |t| t.name == @topic_name }
  end

  def collect_events(queue)
    events = []
    # http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/SQS/Queue.html
    # :batch_size   - maximum number of messages to retrieve per request
    # :idle_timeout - maximum number of seconds to poll while no messages are returned
    queue.poll(:idle_timeout => 5) do |amazon_message|
      sns_message = amazon_message.as_sns_message

      event = parse_event(sns_message)
      events << event if event
    end
    events
  end

  def parse_event(sns_message)
    log_header = "MIQ(#{self.class.name}##{__method__})"
    event = sns_message.body_message_as_h.dup
    message_type = event["messageType"]
    $log.info("#{log_header} Found SNS Message with message type #{message_type}")
    return unless message_type == "ConfigurationItemChangeNotification"

    log_header = "MIQ(#{self.class.name}##{__method__})"
    event["messageId"] = sns_message.message_id
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
    return state_changed ? state_changed["updatedValue"] : change_type
  end

  def sns
    @sns ||= AmazonConnection.sns(@aws_access_key_id, @aws_secret_access_key, @aws_region)
  end

  def sqs
    @sqs ||= AmazonConnection.sqs(@aws_access_key_id, @aws_secret_access_key, @aws_region)
  end
end
