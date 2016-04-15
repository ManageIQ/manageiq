require 'openstack/openstack_event_monitor'
require 'openstack/events/openstack_event'
require 'openstack/events/openstack_ceilometer_event_converter'

class OpenstackCeilometerEventMonitor < OpenstackEventMonitor
  def self.available?(options = {})
    begin
      options[:ems].connect(:service => "Metering")
      return true
    rescue => ex
      $log.debug("Skipping Openstack Ceilometer events. Availability check failed with #{ex}.") if $log
    end
    false
  end

  def self.plugin_priority
    1
  end

  def initialize(options = {})
    @options = options
    @ems = options[:ems]
    @config = options.fetch(:ceilometer, {})
  end

  def start
    @since          = nil
    @monitor_events = true
  end

  def stop
    @monitor_events = false
  end

  def provider_connection
    @provider_connection ||= @ems.connect(:service => "Metering")
  end

  def each_batch
    while @monitor_events
      begin
        $log.info("Quering Openstack Ceilometer for events newer than #{latest_event_timestamp}...") if $log
        events = list_events(query_options).sort_by(&:generated)
        @since = events.last.generated unless events.empty?

        amqp_events = filter_unwanted_events(events).map do |event|
          converted_event = OpenstackCeilometerEventConverter.new(event)
          $log.debug("Openstack Ceilometer is processing a new event: #{event.inspect}") if $log
          openstack_event(nil, converted_event.metadata, converted_event.payload)
        end

        yield amqp_events
      rescue => ex
        $log.info("Reseting Openstack Ceilometer connection after #{ex}.") if $log
        @provider_connection = nil
        provider_connection
      end
    end
  end

  def each
    each_batch do |events|
      events.each { |e| yield e }
    end
  end

  private

  def filter_unwanted_events(events)
    $log.debug("Openstack Ceilometer received a new events batch: (before filtering)") if $log && events.any?
    $log.debug(events.inspect) if $log && events.any?
    @event_type_regex ||= Regexp.new(@config[:event_types_regex].to_s)
    events.select { |event| @event_type_regex.match(event.event_type) }
  end

  def query_options
    [{
      'field' => 'start_timestamp',
      'op'    => 'gt',
      'value' => latest_event_timestamp || ''
    }]
  end

  def list_events(query_options)
    provider_connection.list_events(query_options).body.map do |event_hash|
      Fog::Metering::OpenStack::Event.new(event_hash)
    end
  end

  def latest_event_timestamp
    @since ||= @ems.ems_events.maximum(:timestamp)
  end
end
