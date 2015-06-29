require 'active_support/core_ext'

require_relative '../openstack_event_monitor'
require_relative './openstack_qpid_receiver'
require_relative './openstack_qpid_connection'

class OpenstackQpidEventMonitor < OpenstackEventMonitor
  # The qpid event monitor is available if:
  # 1) the qpid-cpp-client-devel lib is available on this platform (excludes OSX, Windows)
  # 2) a connection can be established, ensuring that the amqp server is
  # indeed qpid (and not another amqp implementation).
  def self.available?(options = {})
    OpenstackQpidConnection.available? && test_connection(options)
  end

  def self.connection_parameters(options = {})
    # TODO: get rid of these "optional" connection parameters altogether
    raise ArgumentError, "hostname and port are required connection parameters" unless options.key?(:hostname) && options.key?(:port)
    username = options[:username] if options.key? :username
    password = options[:password] if options.key? :password
    [
      options[:hostname],
      options[:port],
      username,
      password
    ].compact
  end

  def self.create_connection(options = {})
    OpenstackQpidConnection.new(*connection_parameters(options))
  end

  def self.test_connection(options = {})
    connection = nil
    begin
      connection = create_connection(options)
      connection.open
      connection.open?
    rescue => e
      log_prefix = "MIQ(#{self.name}.#{__method__}) Failed testing qpid amqp connection for #{options[:hostname]}. "
      $log.info("#{log_prefix} The Openstack AMQP service may be using a different provider.  Enable debug logging to see connection exception.") if $log
      $log.debug("#{log_prefix} Exception: #{e}") if $log
      return false
    ensure
      connection.close if connection.respond_to? :close
    end
  end

  def initialize(options = {})
    @options          = options
    @options[:port] ||= DEFAULT_AMQP_PORT
    @receiver_options = @options.slice(:duration, :capacity)
    @client_ip        = @options[:client_ip]

    @collecting_events = false
  end

  def start
    connection.open
    @collecting_events = true
  end

  def stop
    @collecting_events = false
    if @connection
      @connection.close
      @connection = nil
    end
  end

  def each_batch
    while @collecting_events
      events = []
      receivers.each do |receiver|
        events.concat(receiver.get_notifications)
      end
      yield events
    end
  end

  private
  def connection
    @connection ||= create_connection(@options)
  end

  def create_connection(options = {})
    self.class.create_connection(options)
  end

  def receivers
    @receivers ||= initialize_receivers
  end

  def initialize_receivers
    topics.flat_map do |service, topic|
      # The exchange name corresponds to the service name (e.g., nova)
      # OpenStack supports two different exchange variations:
      # v1. <service> (e.g., nova)
      # v2. amq.topic/topic/<service> (e.g., amqp.topic/topic/nova)
      # Create a receiver for each exchange variation per service name
      #
      # The topic corresponds to the message routing key (e.g., # notifications.info)
      # The default topic for all exchanges is "notifications.*" in order to
      # bind to all messages sent to any notification topic.
      [create_v1_receiver(service, topic), create_v2_receiver(service, topic)]
    end
  end

  def topics
    @options[:topics] || {}
  end

  def create_v1_receiver(service, topic)
    OpenstackQpidReceiver.new(connection, service, service, topic, @client_ip, @receiver_options)
  end

  def create_v2_receiver(service, topic)
    exchange = "amq.topic/topic/#{service}"
    OpenstackQpidReceiver.new(connection, service, exchange, topic, @client_ip, @receiver_options)
  end
end
