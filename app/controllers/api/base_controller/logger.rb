module Api
  class BaseController
    module Logger
      def api_log_debug(msg = nil, &block)
        $api_log.debug(msg, &block)
      end

      def api_log_error(msg = nil, &block)
        $api_log.error(msg, &block)
      end

      def api_log_info(msg = nil, &block)
        $api_log.info(msg, &block)
      end
    end
  end
end
