module Api
  class BaseController
    module Logger
      def log_request_initiated
        @requested_at = Time.now.utc
        return unless api_log_info?
        api_log_info(" ")
        log_request("API Request", :requested_at => @requested_at.to_s,
                                   :method       => request.request_method,
                                   :url          => request.original_url)
      end

      def log_api_auth
        return unless api_log_info?
        if @miq_token_hash
          auth_type = "system"
          log_request("System Auth", {:x_miq_token => request.headers[HttpHeaders::MIQ_TOKEN]}.merge(@miq_token_hash))
        else
          auth_type = @auth_token.blank? ? "basic" : "token"
        end
        log_request("Authentication", :type        => auth_type,
                                      :token       => @auth_token,
                                      :x_miq_group => request.headers[HttpHeaders::MIQ_GROUP],
                                      :user        => @auth_user)
        if @auth_user_obj
          group = @auth_user_obj.current_group
          log_request("Authorization", :user   => @auth_user,
                                       :group  => group.description,
                                       :role   => group.miq_user_role_name,
                                       :tenant => group.tenant.name)
        end
      end

      def log_api_request
        @parameter_filter ||= ActionDispatch::Http::ParameterFilter.new(Rails.application.config.filter_parameters)
        return unless api_log_info?
        log_request("Request", @req.to_hash)
        log_request("Parameters", @parameter_filter.filter(params))
        log_request_body
      end

      def log_api_response
        @completed_at = Time.now.utc
        return unless api_log_info?
        log_request("Response", :completed_at => @completed_at.to_s,
                                :size         => '%.3f KBytes' % (response.body.size / 1000.0),
                                :time_taken   => '%.3f Seconds' % (@completed_at - @requested_at),
                                :status       => response.status)
      end

      def api_log_debug?
        $api_log.debug?
      end

      def api_log_info?
        $api_log.info?
      end

      def api_get_method_name(call_stack, method)
        match  = /`(?<mname>[^']*)'/.match(call_stack)
        (match ? match[:mname] : method).sub(/block .*in /, "")
      end

      def api_log_error(msg)
        method = api_get_method_name(caller.first, __method__)
        log_prefix = "MIQ(#{self.class.name}.#{method})"

        $api_log.error("#{log_prefix} #{ApiConfig.base.name} Error")
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

      private

      def log_request_body
        log_request("Body", JSON.pretty_generate(@req.json_body)) if api_log_debug? && @req.json_body.present?
      end

      def log_request(header, data)
        api_log_info("#{('%s:' % header).ljust(15)} #{data}")
      end
    end
  end
end
