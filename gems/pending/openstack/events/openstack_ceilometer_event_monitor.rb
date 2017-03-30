require 'openstack/openstack_event_monitor'
require 'openstack/events/openstack_event'
require 'openstack/events/openstack_ceilometer_event_converter'

class OpenstackCeilometerEventMonitor < OpenstackEventMonitor
  def self.available?(options = {})
    return connect_service_from_settings(options[:ems]) if event_services.keys.include? event_service_settings
    begin
      options[:ems].connect(:service => "Event")
      return true
    rescue MiqException::ServiceNotAvailable => ex
      $log.debug("Skipping Openstack Panko events. Availability check failed with #{ex}. Trying Ceilometer.") if $log
      options[:ems].connect(:service => "Metering")
    end
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
    return @provider_connection ||= self.class.connect_service_from_settings(@ems) if self.class.event_services.keys.include? self.class.event_service_settings
    begin
      @provider_connection ||= @ems.connect(:service => "Event")
    rescue MiqException::ServiceNotAvailable => ex
      $log.debug("Panko is not available, trying access events using Ceilometer (#{ex.inspect})") if $log
      @provider_connection = @ems.connect(:service => "Metering")
    end
  end

  def each_batch
    while @monitor_events
      $log.info("Querying OpenStack for events newer than #{latest_event_timestamp}...") if $log
      events = list_events(query_options).sort_by(&:generated)
      @since = events.last.generated unless events.empty?

      amqp_events = filter_unwanted_events(events).map do |event|
        converted_event = OpenstackCeilometerEventConverter.new(event)
        $log.debug("Processing a new OpenStack event: #{event.inspect}") if $log
        openstack_event(nil, converted_event.metadata, converted_event.payload)
      end

      yield amqp_events
    end
  end

  def each
    each_batch do |events|
      events.each { |e| yield e }
    end
  end

  def self.connect_service_from_settings(ems)
    $log.debug "#{_log.prefix} Using events provided by \"#{event_service_settings}\" service, which was set in settings.yml."
    ems.connect(:service => event_services[event_service_settings])
  end

  def self.event_service_settings
    Settings[:workers][:worker_base][:event_catcher][:event_catcher_openstack_service]
  rescue StandardError => err
    $log.warn "#{_log.prefix} Settings key :event_catcher_openstack_service is missing, #{err}."
    nil
  end

  def self.event_services
    {"panko" => "Event", "ceilometer" => "Metering"}
  end

  private

  def filter_unwanted_events(events)
    $log.debug("Received a new OpenStack events batch: (before filtering)") if $log && events.any?
    $log.debug(events.inspect) if $log && events.any?
    @event_type_regex ||= Regexp.new(@config[:event_types_regex].to_s)
    events.select { |event| @event_type_regex.match(event.event_type) }
  end

  def query_options
    [{
      'field' => 'start_timestamp',
      'op'    => 'ge',
      'value' => latest_event_timestamp || ''
    }]
  end

  def list_events(query_options)
    provider_connection.list_events(query_options).body.map do |event_hash|
      begin
        Fog::Event::OpenStack::Event.new(event_hash)
      rescue NameError
        Fog::Metering::OpenStack::Event.new(event_hash)
      end
    end
  end

  def latest_event_timestamp
    @since ||= @ems.ems_events.maximum(:timestamp)
  end
end
