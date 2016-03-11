require 'openstack/openstack_event_monitor'
require 'openstack/amqp/openstack_amqp_event'
require 'openstack/amqp/openstack_ceilometer_event_converter'

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
        query_options = [{
          'field' => 'start_timestamp',
          'op'    => 'gt',
          'value' => latest_event_timestamp || ''
        }]
        # TODO(maufart): add filtered events fetch method into fog-openstack and refactor then
        events = list_events(query_options).sort_by(&:generated)
        @since = events.last.generated unless events.empty?

        amqp_events = events.map do |event|
          converted_event = OpenstackCeilometerEventConverter.new(event)
          $log.debug("Openstack Ceilometer received a new event:") if $log
          $log.debug(event.inspect) if $log
          amqp_event(nil, converted_event.metadata, converted_event.payload)
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

  def list_events(query_options)
    provider_connection.list_events(query_options).body.map do |event_hash|
      Fog::Metering::OpenStack::Event.new(event_hash)
    end
  end

  def latest_event_timestamp
    @since ||= @ems.ems_events.maximum(:timestamp)
  end
end
