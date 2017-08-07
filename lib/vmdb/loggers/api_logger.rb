require_relative "multicast_logger"

module Vmdb::Loggers
  class ApiLogger < MulticastLogger
    def debug(msg = nil)
      return unless debug?
      prefix = log_prefix(caller.first, __method__)
      (block_given? ? yield : msg).split("\n").each do |l|
        super("#{prefix} #{l}")
      end
    end

    def error(msg = nil)
      return unless error?
      prefix = log_prefix(caller.first, __method__)
      super("#{prefix} API Error")
      (block_given? ? yield : msg).split("\n").each do |l|
        super("#{prefix} #{l}")
      end
    end

    def info(msg = nil)
      return unless info?
      prefix = log_prefix(caller.first, __method__)
      (block_given? ? yield : msg).split("\n").each do |l|
        super("#{prefix} #{l}")
      end
    end

    private

    def log_prefix(backtrace, meth)
      ": MIQ(#{get_method_name(backtrace, meth)})"
    end

    def get_method_name(call_stack, method)
      match = /`(?<mname>[^']*)'/.match(call_stack)
      (match ? match[:mname] : method).sub(/block .*in /, "")
    end
  end
end
