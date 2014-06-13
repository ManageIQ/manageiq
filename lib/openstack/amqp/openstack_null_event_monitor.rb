require_relative '../openstack_event_monitor'

class OpenstackNullEventMonitor < OpenstackEventMonitor
  def self.available?(options)
    false
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
