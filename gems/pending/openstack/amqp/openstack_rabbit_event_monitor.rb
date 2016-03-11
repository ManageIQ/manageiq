require 'openstack/openstack_event_monitor'
require 'openstack/amqp/openstack_amqp_event'
require 'bunny'
require 'thread'

class OpenstackRabbitEventMonitor < OpenstackEventMonitor
  DEFAULT_AMQP_PORT = 5672
  DEFAULT_AMQP_HEARTBEAT = 30

  # The rabbit event monitor is available if a connection can be established.
  # This ensures that the amqp server is indeed rabbit (and not another amqp
  # implementation).
  def self.available?(options = {})
    test_connection(options)
  end

  def self.plugin_priority
    2
  end

  # Why not inline this?
  # It creates a test mock point for specs
  def self.connect(options = {})
    connection_options = {:host => options[:hostname]}
    connection_options[:port]      = options[:port] || DEFAULT_AMQP_PORT
    connection_options[:heartbeat] = options[:heartbeat] || DEFAULT_AMQP_HEARTBEAT
    if options.key? :username
      connection_options[:username] = options[:username]
      connection_options[:password] = options[:password]
    end
    Bunny.new(connection_options)
  end

  def self.test_connection(options = {})
    connection = nil
    begin
      connection = connect(options)
      connection.start
      return true
    rescue => e
      log_prefix = "MIQ(#{name}.#{__method__}) Failed testing rabbit amqp connection for #{options[:hostname]}. "
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
    # protect threaded access to the events array
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
        $log.debug("MIQ(#{self.class.name}) Yielding #{@events.size} events to event_catcher: #{@events.map { |e| e.payload["event_type"] }}") if $log
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

  def initialize_queues(channel)
    remove_legacy_queues
    @queues = {}
    if @options[:topics]
      @options[:topics].each do |exchange, topic|
        amqp_exchange = channel.topic(exchange)
        queue_name = "miq-#{@client_ip}-#{exchange}"
        @queues[exchange] = channel.queue(queue_name, :auto_delete => true, :exclusive => true).bind(amqp_exchange, :routing_key => topic)
      end
    end
  end

  def remove_legacy_queues
    # Rabbit queues used to be created with incorrect initializing arguments (no
    # auto_delete and no exclusive).  The significant problem with leaving these
    # queues around is that they are not deleted when the event monitor
    # disconnects from Rabbit.  And the queues continue to collect messages with
    # no client to drain them.
    channel = connection.create_channel
    @options[:topics].each do |exchange, _topic|
      queue_name = "miq-#{@client_ip}-#{exchange}"
      channel.queue_delete(queue_name) if connection.queue_exists?(queue_name)
    end

    # notifications.* is a poorly named extra-old legacy queue
    queue_name = "notifications.*"
    channel.queue_delete(queue_name) if connection.queue_exists?(queue_name)

    channel.close
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
