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
    @ems          = ems
    @topic_name   = sns_aws_config_topic_name
    @stop_polling = false
    @before_poll  = nil
  end

  #
  # Stop capturing events
  #
  def stop
    @stop_polling = true
  end

  def before_poll(&block)
    @before_poll = block
  end

  #
  # Collect events off the appliance-specific queue and return the events as a
  # batch to the caller.
  #
  # :yield: array of Amazon events as hashes
  #
  def poll
    @ems.with_provider_connection(:service => :SQS, :sdk_v2 => true) do |sqs|
      queue_poller = Aws::SQS::QueuePoller.new(
        find_or_create_queue,
        :client            => sqs.client,
        :wait_time_seconds => 20,
        :before_request    => @before_poll
      )
      begin
        queue_poller.poll do |sqs_message|
          $aws_log.debug("#{log_header} received message #{sqs_message}")
          throw :stop_polling if @stop_polling
          event = parse_event(sqs_message)
          yield event if event
        end
      rescue Aws::SQS::Errors::ServiceError => exception
        raise ProviderUnreachable, exception.message
      end
    end
  end

  private

  # @return [String] is a queue_url
  def find_or_create_queue
    queue_url = sqs_get_queue_url(queue_name)
    subscribe_topic_to_queue(sns_topic, queue_url) unless queue_subscribed_to_topic?(queue_url, sns_topic)
    add_policy_to_queue(queue_url, sns_topic.arn) unless queue_has_policy?(queue_url, sns_topic.arn)
    queue_url
  rescue Aws::SQS::Errors::NonExistentQueue
    $aws_log.info("#{log_header} Amazon SQS Queue #{queue_name} does not exist; creating queue")
    queue_url = sqs_create_queue(queue_name)
    subscribe_topic_to_queue(sns_topic, queue_url)
    add_policy_to_queue(queue_url, sns_topic.arn)
    $aws_log.info("#{log_header} Created Amazon SQS Queue #{queue_name} and subscribed to AWSConfig_topic")
    queue_url
  rescue Aws::SQS::Errors::ServiceError => exception
    raise ProviderUnreachable, exception.message
  end

  def queue_has_policy?(queue_url, topic_arn)
    policy_attribute = 'Policy'
    policy = @ems.with_provider_connection(:service => :SQS, :sdk_v2 => true) do |sqs|
      sqs.client.get_queue_attributes(
        :queue_url       => queue_url,
        :attribute_names => [policy_attribute]
      ).attributes[policy_attribute]
    end

    policy == queue_policy(queue_url_to_arn(queue_url), topic_arn)
  end

  def queue_subscribed_to_topic?(queue_url, topic)
    queue_arn = queue_url_to_arn(queue_url)
    topic.subscriptions.any? { |subscription| subscription.attributes['Endpoint'] == queue_arn }
  end

  def sqs_create_queue(queue_name)
    @ems.with_provider_connection(:service => :SQS, :sdk_v2 => true) do |sqs|
      sqs.client.create_queue(:queue_name => queue_name).queue_url
    end
  end

  def sqs_get_queue_url(queue_name)
    $aws_log.debug("#{log_header} Looking for Amazon SQS Queue #{queue_name} ...")
    @ems.with_provider_connection(:service => :SQS, :sdk_v2 => true) do |sqs|
      sqs.client.get_queue_url(:queue_name => queue_name).queue_url
    end
  end

  # @return [Aws::SNS::Topic] the found topic
  # @raise [ProviderUnreachable] in case the topic is not found
  def sns_topic
    @ems.with_provider_connection(:service => :SNS, :sdk_v2 => true) do |sns|
      sns.topics.detect { |t| t.arn.split(/:/)[-1] == @topic_name }
    end || begin
      $aws_log.warn("#{log_header} Unable to find the AWS Config Topic '#{@topic_name}'. " \
      "Cannot collect Amazon events for AWS Access Key ID #{@ems.authentication_userid}")
      $aws_log.warn("#{log_header} Contact Amazon to create the AWS Config service and topic for Amazon events.")
      raise ProviderUnreachable, "Unable to find the AWS Config Topic '#{@topic_name}'"
    end
  end

  # @param [Aws::SNS::Topic] topic
  def subscribe_topic_to_queue(topic, queue_url)
    queue_arn = queue_url_to_arn(queue_url)
    $aws_log.info("#{log_header} Subscribing Queue #{queue_url} to #{topic.arn}")
    subscription = topic.subscribe(:protocol => 'sqs', :endpoint => queue_arn)
    raise ProviderUnreachable, "Can't subscribe to #{queue_arn}" unless subscription.arn.present?
  end

  def add_policy_to_queue(queue_url, topic_arn)
    queue_arn = queue_url_to_arn(queue_url)
    policy    = queue_policy(queue_arn, topic_arn)

    @ems.with_provider_connection(:service => :SQS, :sdk_v2 => true) do |sqs|
      sqs.client.set_queue_attributes(
        :queue_url  => queue_url,
        :attributes => {'Policy' => policy}
      )
    end
  end

  def queue_url_to_arn(queue_url)
    @queue_url_to_arn ||= {}
    @queue_url_to_arn[queue_url] ||= begin
      arn_attribute = "QueueArn"
      @ems.with_provider_connection(:service => :SQS, :sdk_v2 => true) do |sqs|
        sqs.client.get_queue_attributes(
          :queue_url       => queue_url,
          :attribute_names => [arn_attribute]
        ).attributes[arn_attribute]
      end
    end
  end

  # @param [Aws::SQS::Types::Message] message
  def parse_event(message)
    event = JSON.parse(JSON.parse(message.body)['Message'])
    $log.info("#{log_header} Found SNS Message with message type #{event["messageType"]}")
    return unless event["messageType"] == "ConfigurationItemChangeNotification"

    event["messageId"] = message.message_id
    event["eventType"] = parse_event_type(event)
    $log.info("#{log_header} Parsed event from SNS Message #{event["eventType"]}")
    event
  rescue JSON::ParserError => err
    $log.error("#{log_header} JSON::ParserError parsing '#{message.body}' - #{err.message}")
    nil
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

  def log_header
    @log_header ||= "MIQ(#{self.class.name}#)"
  end

  def queue_name
    @queue_name ||= "manageiq-awsconfig-queue-#{@ems.guid}"
  end

  def queue_policy(queue_arn, topic_arn)
    <<EOT
{
  "Version": "2012-10-17",
  "Id": "#{queue_arn}/SQSDefaultPolicy",
  "Statement": [
    {
      "Sid": "#{Digest::MD5.hexdigest(queue_arn)}",
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": "SQS:SendMessage",
      "Resource": "#{queue_arn}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "#{topic_arn}"
        }
      }
    }
  ]
}
EOT
  end
end
