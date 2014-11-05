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

  def self.test_connection(options = {})
    connection = nil
    begin
      connection = OpenstackQpidConnection.new(options)
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
    $log.info("#{__FILE__}  initialize options  #{options}")

    @options = options
    @options[:port] ||= DEFAULT_AMQP_PORT
    @receiver_options = options.slice(:duration, :capacity)
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
    $log.info("#{__FILE__}  connection options  #{options}")

    @connection ||= create_connection(@options)
  end

  def create_connection(options={})
    OpenstackQpidConnection.new(options)
  end

  def receivers
    @receivers ||= initialize_receivers
  end

  def initialize_receivers
    topics.collect {|exchange, topic| create_receiver(exchange, topic) }
  end

  def topics
    @options[:topics] || {}
  end

  def create_receiver(exchange, topic)
    OpenstackQpidReceiver.new(connection.session, exchange, topic, @receiver_options)
  end
end
