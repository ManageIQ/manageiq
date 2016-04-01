class ManageIQ::Providers::Azure::CloudManager::EventCatcher::Stream
  #
  # Creates an event monitor
  #
  def initialize(client_id, client_key, azure_region, tenant_id)
    @client_id         = client_id
    @client_key        = client_key
    @tenant_id         = tenant_id
    @azure_region      = azure_region
    @collecting_events = false
  end

  # Start capturing events
  def start
    @collecting_events = true
  end

  # Stop capturing events
  def stop
    @collecting_events = false
  end

  def each_batch
    while @collecting_events
      yield get_events.collect { |e| JSON.parse(e) }
    end
  end

  private

  def get_events
    # Grab only events for the last minute if this is the first poll
    filter = @since ? "eventTimestamp ge #{@since}" : "eventTimestamp ge #{startup_interval}"
    events = connection.list(:filter => filter, :all => true).sort_by(&:event_timestamp)

    # HACK: the Azure Insights API does not support the 'gt' (greater than relational operator)
    # therefore we have to poll from 1 millisecond past the timestamp of the last event to avoid
    # gathering the same event more than once.
    @since = one_ms_from_last_timestamp(events) unless events.empty?
    events
  end

  def startup_interval
    (Time.current - 1.minute).httpdate
  end

  def one_ms_from_last_timestamp(events)
    time = Time.at(one_ms_from_last_timestamp_as_f(events)).utc
    format_timestamp(time)
  end

  def one_ms_from_last_timestamp_as_f(events)
    Time.zone.parse(events.last.event_timestamp).to_f + 0.001
  end

  def format_timestamp(time)
    time.strftime('%Y-%m-%dT%H:%M:%S.%L')
  end

  def connection
    @connection ||= create_event_service
  end

  def create_event_service
    conf = Azure::Armrest::ArmrestService.configure(
      :client_id  => @client_id,
      :client_key => @client_key,
      :tenant_id  => @tenant_id
    )
    Azure::Armrest::Insights::EventService.new(conf)
  end
end
