module Vmdb
  class Deprecation
    def self.instance
      @instance ||= ActiveSupport::Deprecation.new("H-release", "ManageIQ").tap { |d| d.behavior = default_behavior }
    end

    def self.method_missing(method_name, *args, &block)
      instance.respond_to?(method_name) ? instance.send(method_name, *args, &block) : super
    end

    def self.respond_to_missing?(method, _include_private = false)
      instance.respond_to?(method)
    end

    class << self
      delegate :silence, :warn, :to => :instance
    end

    def self.default_behavior
      [proc_for_default_log].tap { |a| a << ActiveSupport::Deprecation::DEFAULT_BEHAVIORS[:stderr] unless Rails.env.production? }
    end
    private_class_method :default_behavior

    def self.default_log
      $log
    end
    private_class_method :default_log

    def self.proc_for_default_log
      return unless default_log
      proc do |message, callstack|
        default_log.warn(message)
        default_log.debug { callstack.join("\n  ") } unless Rails.env.production?
      end
    end
    private_class_method :proc_for_default_log
  end
end
