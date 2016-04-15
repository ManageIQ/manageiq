require 'openstack/openstack_event_monitor'

class OpenstackNullEventMonitor < OpenstackEventMonitor
  def self.available?(_options)
    false
  end

  def self.plugin_priority
    # make the null event monitor the lowest priority
    DEFAULT_PLUGIN_PRIORITY - 1
  end

  def initialize(options = {})
    $log.warn("MIQ(#{self.class.name}##{__method__}) There was an problem establishing a connection to the AMQP"\
              " service on #{options[:hostname]}. Check the evm.log for more details.")
    @options = options
  end

  def start
  end

  def stop
  end

  def each_batch
    # yield empty array to enter the each_batch block and trigger sleep
    # to avoid smashing the CPU with a tight loop
    yield []
  end
end
