require 'bunny'
require 'thread'

# Listens to RabbitMQ events
class ManageIQ::Providers::Vmware::CloudManager::EventCatcher::Stream
  def self.test_amqp_connection(options = {})
    connection = nil
    begin
      connection = connect(options)
      connection.start
      return true
    rescue Bunny::AuthenticationFailureError => e
      $log.info("#{log_prefix} Failed testing rabbit amqp connection: #{e.message}")
      raise MiqException::MiqInvalidCredentialsError.new "Login failed due to a bad username or password."
    rescue Bunny::TCPConnectionFailedForAllHosts => e
      raise MiqException::MiqHostError.new "Socket error: #{e.message}"
    rescue
      $log.info("#{log_prefix} Failed testing rabbit amqp connection for #{options[:hostname]}. ")
      raise
    ensure
      connection.close if connection.respond_to? :close
    end
  end

  def self.connect(connection_options = {})
    Bunny.new(connection_options)
  end

  def self.log_prefix
    "MIQ(#{self.class.name})"
  end

  def initialize(options = {})
    @options          = options
    @client_ip        = @options[:client_ip]
    @collecting_events = false

    # protect threaded access to the events array
    @events_array_mutex = Mutex.new
    @events = []
  end

  def start
    $log.debug("#{self.class.log_prefix} Opening amqp connection to #{@options}")
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
    listen_queues
    while @collecting_events
      @events_array_mutex.synchronize do
        yield @events
        @events.clear
      end
      sleep 5
    end
  end

  private

  def connection
    @connection ||= self.class.connect(@options)
  end

  def initialize_queues(channel)
    @queues = {}
    @options[:queues].each do |queue_name|
      begin
        @queues[queue_name] = channel.queue(queue_name, :durable => true)
      rescue Bunny::AccessRefused => err
        $log.warn("#{self.class.log_prefix} Could not start listening to queue '#{queue_name}' due to: #{err}")
      end
    end
  end

  def listen_queues
    @queues.each do |queue_name, queue|
      queue.subscribe do |delivery_info, metadata, payload|
        begin

          # Parse amqp message
          event = ManageIQ::Providers::Vmware::CloudManager::EventCatcher::Event.new(payload, metadata, delivery_info)

          # Ignore message if not related to event, see link below
          if event.type.start_with? "com/vmware/vcloud/event/"
            @events_array_mutex.synchronize do
              @events << event
            end
          end
        rescue => e
          $log.error("#{self.class.log_prefix} Exception receiving Rabbit (amqp)"\
                     " event on #{queue_name} from #{@options[:hostname]}: #{e}")
        end
      end
    end
  end
end
