require 'openstack/openstack_event_monitor'

class OpenstackNullEventMonitor < OpenstackEventMonitor
  def self.available?(options)
    false
  end

  def self.plugin_priority
    # make the null event monitor the lowest priority
    DEFAULT_PLUGIN_PRIORITY - 1
  end

  def initialize(options = {})
    @options = options
  end

  def start
    raise NotImplementedError, error_message
  end

  def stop
    raise NotImplementedError, error_message
  end

  def each_batch
    raise NotImplementedError, error_message
  end

  private
  def error_message
    @error_message ||= "Openstack Event Monitoring is not available for #{@options[:hostname]}.  Check logs for more details."
  end
end
