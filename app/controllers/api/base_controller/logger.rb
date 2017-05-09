module Api
  class BaseController
    module Logger
      def log_request_initiated
        @requested_at = Time.now.utc
        return unless api_log_info?
        api_log_info { " " }
        api_log_info do
          format_data_for_logging("API Request",
                                  :requested_at => @requested_at.to_s,
                                  :method       => request.request_method,
                                  :url          => request.original_url)
        end
      end

      def log_api_auth
        return unless api_log_info?
        if @miq_token_hash
          auth_type = "system"
          api_log_info do
            format_data_for_logging(
              "System Auth",
              {:x_miq_token => request.headers[HttpHeaders::MIQ_TOKEN]}.merge(@miq_token_hash)
            )
          end
        else
          auth_type = request.headers[HttpHeaders::AUTH_TOKEN].blank? ? "basic" : "token"
        end

        api_log_info do
          format_data_for_logging("Authentication",
                                  :type        => auth_type,
                                  :token       => request.headers[HttpHeaders::AUTH_TOKEN],
                                  :x_miq_group => request.headers[HttpHeaders::MIQ_GROUP],
                                  :user        => User.current_user.userid)
        end
        if User.current_user
          group = User.current_user.current_group
          api_log_info do
            format_data_for_logging("Authorization",
                                    :user   => User.current_user.userid,
                                    :group  => group.description,
                                    :role   => group.miq_user_role_name,
                                    :tenant => group.tenant.name)
          end
        end
      end

      def log_api_request
        @parameter_filter ||= ActionDispatch::Http::ParameterFilter.new(Rails.application.config.filter_parameters)
        return unless api_log_info?
        api_log_info { format_data_for_logging("Request", @req.to_hash) }

        api_log_info do
          unfiltered_params = request.query_parameters
                                     .merge(params.permit(:action, :controller, :format).to_h)
                                     .merge("body" => @req.json_body)
          format_data_for_logging("Parameters", @parameter_filter.filter(unfiltered_params))
        end
        log_request_body
      end

      def log_api_response
        @completed_at = Time.now.utc
        return unless api_log_info?
        api_log_info do
          format_data_for_logging("Response",
                                  :completed_at => @completed_at.to_s,
                                  :size         => '%.3f KBytes' % (response.body.size / 1000.0),
                                  :time_taken   => '%.3f Seconds' % (@completed_at - @requested_at),
                                  :status       => response.status)
        end
      end

      def api_log_debug?
        $api_log.debug?
      end

      def api_log_info?
        $api_log.info?
      end

      def api_get_method_name(call_stack, method)
        match = /`(?<mname>[^']*)'/.match(call_stack)
        (match ? match[:mname] : method).sub(/block .*in /, "")
      end

      def api_log_error(msg = nil)
        return unless $api_log.error?
        prefix = log_prefix(caller.first, __method__)
        $api_log.error("#{prefix} #{ApiConfig.base.name} Error")
        (block_given? ? yield : msg).split("\n").each do |l|
          $api_log.error("#{prefix} #{l}")
        end
      end

      def api_log_debug(msg = nil)
        return unless $api_log.debug?
        prefix = log_prefix(caller.first, __method__)
        (block_given? ? yield : msg).split("\n").each do |l|
          $api_log.debug("#{prefix} #{l}")
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

      def log_request_body
        if api_log_debug? && @req.json_body.present?
          api_log_info { format_data_for_logging("Body", JSON.pretty_generate(@req.json_body)) }
        end
      end

      def format_data_for_logging(header, data)
        "#{('%s:' % header).ljust(15)} #{data}"
      end
    end
  end
end
