class OvirtEventMonitor
  def initialize(options = {})
    @options = options
  end

  def inventory
    require 'ovirt'
    @inventory ||= Ovirt::Inventory.new(@options)
  end

  def start
    trap(:TERM) { $rhevm_log.info "EventMonitor#start: ignoring SIGTERM" }
    @since          = nil
    @inventory      = nil
    @monitor_events = true
  end

  def stop
    @monitor_events = false
  end

  def each_batch
    while @monitor_events
      # grab only the most recent event if this is the first time through
      query_options = @since ? {:since => @since} : {:max => 1}
      events = inventory.events(query_options).sort_by { |e| e[:id].to_i }
      @since = events.last[:id].to_i unless events.empty?

      yield events
    end
  end

  def each
    each_batch do |events|
      events.each { |e| yield e }
    end
  end
end
