module ApiHelper
  module Logger
    def api_log_debug?
      $api_log.debug?
    end

    def api_get_method_name(call_stack, method)
      match  = /`(?<mname>[^']*)'/.match(call_stack)
      (match ? match[:mname] : method).sub(/block .*in /, "")
    end

    def api_log_error(msg)
      method = api_get_method_name(caller.first, __method__)
      log_prefix = "MIQ(#{self.class.name}.#{method})"

      $api_log.error("#{log_prefix} #{@name} Error")
      msg.split("\n").each { |l| $api_log.error("#{log_prefix} #{l}") }
    end

    def api_log_debug(msg)
      if api_log_debug?
        method = api_get_method_name(caller.first, __method__)
        log_prefix = "MIQ(#{self.class.name}.#{method})"

        msg.split("\n").each { |l| $api_log.info("#{log_prefix} #{l}") }
      end
    end

    def api_log_info(msg)
      method = api_get_method_name(caller.first, __method__)
      log_prefix = "MIQ(#{self.class.name}.#{method})"

      msg.split("\n").each { |l| $api_log.info("#{log_prefix} #{l}") }
    end
  end
end
