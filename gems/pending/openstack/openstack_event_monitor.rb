# The OpentstackEventMonitor uses a plugin pattern to instantiate the correct
# subclass as a plugin based on the #available? class method implemented in each
# subclass
require 'more_core_extensions/core_ext/hash'
require 'util/extensions/miq-module'
require 'active_support/core_ext/class/subclasses'

class OpenstackEventMonitor
  def self.new(options = {})
    # plugin initializer
    self == OpenstackEventMonitor ? event_monitor(options) : super
  end

  def self.available?(options)
    event_monitor_class(options) != OpenstackNullEventMonitor
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
    super.sort_by(&:plugin_priority).reverse
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
  def initialize(_options = {})
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
      events.each { |e| yield e }
    end
  end

  cache_with_timeout(:event_monitor_class_cache) { Hash.new }
  cache_with_timeout(:event_monitor_cache) { Hash.new }

  def self.event_monitor_class(options)
    key = event_monitor_key(options)
    event_monitor_class_cache[key] ||= begin
      detected_event_monitor = subclasses.detect do |event_monitor|
        begin
          event_monitor.available?(options)
        rescue => e
          $log.warn("MIQ(#{self}.#{__method__}) Error occured testing #{event_monitor}
                     for #{options[:hostname]}. Trying other AMQP clients.  #{e.message}")
          false
        end
      end
      detected_event_monitor || OpenstackNullEventMonitor
    end
  end

  # Select the best-fit plugin, or OpenstackNullEventMonitor if no plugin will
  # work Return the plugin instance
  # Caches plugin instances by openstack provider
  def self.event_monitor(options)
    key = event_monitor_key(options)
    event_monitor_cache[key] ||= event_monitor_class(options).new(options)
  end

  # this private marker is really here for looks
  # private_class_methods are marked below

  private

  def self.event_monitor_key(options)
    options.values_at(:hostname, :port, :security_protocol, :username, :password)
  end
  private_class_method :event_monitor_key

  def openstack_event(_delivery_info, metadata, payload)
    OpenstackEvent.new(payload,
                       :user_id      => payload["user_id"],
                       :priority     => metadata["priority"],
                       :content_type => metadata["content_type"],
                      )
  end
end

# Dynamically load all event monitor plugins
Dir.glob(File.join(File.dirname(__FILE__), "events/*event_monitor.rb")).each { |f| require f }
