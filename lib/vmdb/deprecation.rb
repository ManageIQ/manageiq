module Vmdb
  class Deprecation
    def self.instance
      @instance ||= begin
        deprecator = ActiveSupport::Deprecation.new("D-release", "ManageIQ")
        deprecator.behavior = [:stderr, :log]
        deprecator
      end
    end

    def self.method_missing(method_name, *args, &block)
      instance.respond_to?(method_name) ? instance.send(method_name, *args, &block) : super
    end

    def self.respond_to_missing?(method, _include_private = false)
      instance.respond_to?(method)
    end
  end
end
