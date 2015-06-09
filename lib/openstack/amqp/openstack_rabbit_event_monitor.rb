require_relative '../openstack_event_monitor'
require_relative './openstack_amqp_event'
require 'bunny'
require 'thread'

class OpenstackRabbitEventMonitor < OpenstackEventMonitor
  # The rabbit event monitor is available if a connection can be established.
  # This ensures that the amqp server is indeed rabbit (and not another amqp
  # implementation).
  def self.available?(options = {})
    test_connection(options)
  end

  def self.plugin_priority
    1
  end

  # Why not inline this?
  # It creates a test mock point for specs
  def self.connect(options={})
    connection_options = {:host => options[:hostname]}
    connection_options[:port] = options[:port] || DEFAULT_AMQP_PORT
    if options.key? :username
      connection_options[:username] = options[:username]
      connection_options[:password] = options[:password]
    end
    Bunny.new(connection_options)
  end

  def self.test_connection(options={})
    connection = nil
    begin
      connection = connect(options)
      connection.start
      return true
    rescue => e
      log_prefix = "MIQ(#{self.name}.#{__method__}) Failed testing rabbit amqp connection for #{options[:hostname]}. "
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
    @client_ip        = @options[:client_ip]

    @collecting_events = false
    @events = []
    #protect threaded access to the events array
    @events_array_mutex = Mutex.new
  end

  def start
    connection.start
    @channel = connection.create_channel
    initialize_queues(@channel)
  end

  def stop
    @connection.close if @connection.respond_to? :close
    @collecting_events = false
  end

  def each_batch
    @collecting_events = true
    subscribe_queues
    while @collecting_events
      @events_array_mutex.synchronize do
        $log.debug("MIQ(#{self.class.name}) Yielding #{@events.size} events to event_catcher: #{@events.map{|e| e.payload["event_type"]}}") if $log
        yield @events
        $log.debug("MIQ(#{self.class.name}) Clearing events") if $log
        @events.clear
      end
      sleep 5
    end
  end

  private
  def connection
    @connection ||= OpenstackRabbitEventMonitor.connect(@options)
  end

  def amqp_event(delivery_info, metadata, payload)
    OpenstackAmqpEvent.new(payload,
      :user_id        => payload["user_id"],
      :priority       => metadata["priority"],
      :content_type   => metadata["content_type"],
    )
  end

  def initialize_queues(channel)
    @queues = {}
    if @options[:topics]
      @options[:topics].each do |exchange, topic|
        amqp_exchange = channel.topic(exchange)
        queue_name = "miq-#{@client_ip}-#{exchange}"
        @queues[exchange] = channel.queue(queue_name).bind(amqp_exchange, :routing_key => topic)
      end
    end
  end

  def subscribe_queues
    @queues.each do |exchange, queue|
      queue.subscribe do |delivery_info, metadata, payload|
        begin
          payload = JSON.parse(payload)
          event = amqp_event(delivery_info, metadata, payload)
          @events_array_mutex.synchronize do
            @events << event
            $log.debug("MIQ(#{self.class.name}##{__method__}) Received Rabbit (amqp) event on #{exchange} from #{@options[:hostname]}: #{payload["event_type"]}") if $log
          end
        rescue e
          $log.error("MIQ(#{self.class.name}##{__method__}) Exception receiving Rabbit (amqp) event on #{exchange} from #{@options[:hostname]}: #{e}") if $log
        end
      end
    end
  end
end
