module Vmdb
  class Deprecation
    def self.instance
      @instance ||= begin
        deprecator = ActiveSupport::Deprecation.new("D-release", "ManageIQ")
        deprecator.behavior = [evm_log]
        deprecator.behavior << ActiveSupport::Deprecation::DEFAULT_BEHAVIORS[:stderr] unless Rails.env.production?
        deprecator
      end
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

    private

    def self.evm_log
      proc do |message, callstack|
        next unless defined?($log)
        $log.warn message
        $log.debug callstack.join("\n  ") if $log.debug?
      end
    end
    private_class_method :evm_log
  end
end
