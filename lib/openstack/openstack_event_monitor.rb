# The OpentstackEventMonitor uses a plugin pattern to instantiate the correct
# subclass as a plugin based on the #available? class method implemented in each
# subclass
require 'more_core_extensions/core_ext/hash'

class OpenstackEventMonitor
  DEFAULT_AMQP_PORT = 5672

  def self.new(options={})
    # plugin initializer
    self == OpenstackEventMonitor ? select_event_monitor(options) : super
  end

  def self.available?(options)
    !select_event_monitor_class(options).kind_of? OpenstackNullEventMonitor
  end

  DEFAULT_PLUGIN_PRIORITY = 0
  # Subclasses can override plugin priority to receive preferential treatment.
  # The higher the plugin_priority, the ealier the plugin will be tested for
  # availability.
  def self.plugin_priority
    DEFAULT_PLUGIN_PRIORITY
  end

  # Overridden for plugin support.  Allows this parent class to provide an
  # ordering of plugins.
  def self.subclasses
    # sort plugins on plugin_priorty
    super.sort_by(&:plugin_priority)
  end

  # TODO: when ceilometer event integration is in place, this will likely have
  # to move to a lower level .. possibly to an AMQP specific layer of event
  # monitor selection ...
  # Need to consider how this will impact the model for legacy amqp connection
  # testing
  def self.test_amqp_connection(options)
    available?(options)
  end

  # See OpenstackEventMonitor.new for details on event monitor selection
  def initialize(options = {})
    # See OpenstackEventMonitor.new
    raise NotImplementedError, "Cannot instantiate OpenstackEventMonitor directly."
  end

  def start
    raise NotImplementedError, "must be implemented in subclass"
  end

  def stop
    raise NotImplementedError, "must be implemented in subclass"
  end

  def each_batch
    raise NotImplementedError, "must be implemented in subclass"
  end

  def each
    each_batch do |events|
      events.each {|e| yield e}
    end
  end

  # this private marker is really here for looks
  # private_class_methods are marked below
  private

  # Select the best-fit plugin, or OpenstackNullEventMonitor if no plugin will
  # work Return the plugin instance
  # Caches plugin instances by openstack provider
  def self.select_event_monitor(options)
    cache_result(:instances, event_monitor_key(options)) do
      select_event_monitor_class(options).new(options)
    end
  end
  private_class_method :select_event_monitor

  def self.select_event_monitor_class(options)
    cache_result(:plugin_classes, event_monitor_key(options)) do
      self.subclasses.detect do |event_monitor|
        begin
          event_monitor.available?(options)
        rescue => e
          $log.error("MIQ(#{self}.#{__method__}) Error occured testing #{event_monitor} for #{options[:hostname]}. Trying other AMQP clients.  #{e.message}")
          false
        end
      end || OpenstackNullEventMonitor
    end
  end
  private_class_method :select_event_monitor_class

  def self.cache_result(cache_name, key)
    @cache ||= {}
    @cache.fetch_path(cache_name, key) || @cache.store_path(cache_name, key, yield)
  end
  private_class_method :cache_result

  def self.event_monitor_key(options)
    options.values_at(:hostname, :username, :password)
  end
  private_class_method :event_monitor_key
end

# Dynamically load all event monitor plugins
Dir.glob(File.join(File.dirname(__FILE__), "amqp/*event_monitor.rb")).each { |f| require f }
