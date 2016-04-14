class ManageIQ::Providers::Hawkular::MiddlewareManager::EventCatcher::Stream
  def initialize(ems)
    @ems               = ems
    @alerts_client     = ems.alerts_connect
    @collecting_events = false
  end

  def start
    @collecting_events = true
  end

  def stop
    @collecting_events = false
  end

  def each_batch
    while @collecting_events
      yield fetch
    end
  end

  private

  # Each fetch is performed from the time of the most recently caught event or 1 minute back for the first poll.
  # This gives us some slack if hawkular events are timestamped behind the miq server time.
  # Note: This assumes all Hawkular events at max-time T are fetched in one call. It is unlikely that there
  # would be more than one for the same millisecond, and that the query would be performed in the midst of
  # writes for the same ms. It may be a feasible scenario but I think it's unnecessary to handle it at this time.
  def fetch
    @start_time ||= (Time.current - 1.minute).to_i * 1000
    $mw_log.debug "Catching Events since [#{@start_time}]"

    new_events = @alerts_client.list_events("startTime" => @start_time)
    @start_time = new_events.max_by(&:ctime).ctime + 1 unless new_events.empty? # add 1 ms to avoid dups with GTE filter
    new_events
  rescue => err
    $mw_log.info "Error capturing events #{err}"
    []
  end
end
