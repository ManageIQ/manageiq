require 'more_core_extensions/core_ext/hash'
require 'util/extensions/miq-module'
require 'vmware/events/vmware_vcloud_event'
require 'bunny'
require 'thread'

# Listens to RabbitMQ events
class VmwareVcloudEventMonitor
  DEFAULT_AMQP_PORT = 5672
  DEFAULT_AMQP_HEARTBEAT = 30

  def self.test_connection(options = {})
    connection = nil
    begin
      connection = connect(options)
      connection.start
      return true
    rescue Bunny::AuthenticationFailureError => e
      $log.info("#{log_prefix} Failed testing rabbit amqp connection: #{e.message}") if $log
      raise MiqException::MiqInvalidCredentialsError.new "Login failed due to a bad username or password."
    rescue Bunny::TCPConnectionFailedForAllHosts => e
      raise MiqException::MiqHostError.new "Socket error: #{e.message}"
    rescue
      $log.info("#{log_prefix} Failed testing rabbit amqp connection for #{options[:hostname]}. ") if $log
      raise
    ensure
      connection.close if connection.respond_to? :close
    end
  end

  def self.available?(options = {})
    test_connection(options)
  end

  def self.test_amqp_connection(options)
    available?(options)
  end

  def self.connect(options = {})
    connection_options = {:host => options[:hostname]}
    connection_options[:port]               = options[:port] || DEFAULT_AMQP_PORT
    connection_options[:heartbeat]          = options[:heartbeat] || DEFAULT_AMQP_HEARTBEAT
    connection_options[:automatic_recovery] = options[:automatic_recovery] if options.key? :automatic_recovery
    connection_options[:recovery_attempts]  = options[:recovery_attempts] if options.key? :recovery_attempts

    if options.key? :recover_from_connection_close
      connection_options[:recover_from_connection_close] = options[:recover_from_connection_close]
    end

    if options.key? :username
      connection_options[:username] = options[:username]
      connection_options[:password] = options[:password]
    end
    Bunny.new(connection_options)
  end

  def self.log_prefix
    "MIQ(#{self.class.name})"
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
    $log.debug("#{self.class.log_prefix} Opening amqp connection to #{@options}") if $log
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
        $log.debug("#{self.class.log_prefix} Yielding #{@events.size} events to" \
                   " event_catcher: #{@events.map { |e| e.payload["event_type"] }}") if $log
        yield @events
        $log.debug("#{self.class.log_prefix} Clearing events") if $log
        @events.clear
      end
      sleep 5
    end
  end

  def each
    each_batch do |events|
      events.each { |e| yield e }
    end
  end

  private

  def connection
    @connection ||= self.class.connect(@options)
  end

  def initialize_queues(channel)
    @queues = {}
    @options[:queues].each do |queue_name|
      @queues[queue_name] = channel.queue(queue_name, :durable => true)
    end
  end

  def subscribe_queues
    @queues.each do |queue_name, queue|
      # Parse amqp message
      queue.subscribe do |delivery_info, metadata, payload|
        begin
          event = VmwareVcloudEvent.new(payload, metadata, delivery_info)
          @events_array_mutex.synchronize do
            @events << event
            $log.debug("#{self.class.log_prefix} Received Rabbit (amqp) event"\
                       " on #{queue_name} from #{@options[:hostname]}: #{event}") if $log
          end
        rescue => e
          $log.error("#{self.class.log_prefix} Exception receiving Rabbit (amqp)"\
                     " event on #{queue_name} from #{@options[:hostname]}: #{e}") if $log
        end
      end
    end
  end
end
