module Api
  class BaseController
    module Logger
      def api_get_method_name(call_stack, method)
        match = /`(?<mname>[^']*)'/.match(call_stack)
        (match ? match[:mname] : method).sub(/block .*in /, "")
      end

      def api_log_debug(msg = nil)
        return unless $api_log.debug?
        prefix = log_prefix(caller.first, __method__)
        (block_given? ? yield : msg).split("\n").each do |l|
          $api_log.debug("#{prefix} #{l}")
        end
      end

      def api_log_error(msg = nil)
        return unless $api_log.error?
        prefix = log_prefix(caller.first, __method__)
        $api_log.error("#{prefix} #{ApiConfig.base.name} Error")
        (block_given? ? yield : msg).split("\n").each do |l|
          $api_log.error("#{prefix} #{l}")
        end
      end

      def api_log_info(msg = nil)
        return unless $api_log.info
        prefix = log_prefix(caller.first, __method__)
        (block_given? ? yield : msg).split("\n").each do |l|
          $api_log.info("#{prefix} #{l}")
        end
      end

      private

      def log_prefix(backtrace, meth)
        "MIQ(#{self.class.name}.#{api_get_method_name(backtrace, meth)})"
      end
    end
  end
end
