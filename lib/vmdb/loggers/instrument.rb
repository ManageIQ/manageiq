module Vmdb
  module Loggers
    module Instrument
      # To be used as Excon's request logger, the logger must respond to
      #   #instrument as in ActiveSupport::Notifications.
      #   Implementation derived from Excon::StandardInstrumentor
      def instrument(name, params = {})
        method, message =
          case name
          when "excon.request" then  [:debug, message_for_excon_request(params)]
          when "excon.response" then [:debug, message_for_excon_response(params)]
          when "excon.error" then    [:debug, message_for_excon_error(params)]
          else                   [:debug, message_for_other(params)]
          end

        send(method, "#{name.ljust(14)}  #{message}")
        yield if block_given?
      end

      private

      def message_for_excon_request(params)
        uri_parts    = params.values_at(:scheme, nil, :host, :port, nil, :path, nil, nil, nil)
        uri_parts[3] = uri_parts[3].to_i if uri_parts[3] # port
        uri          = {:uri => URI::Generic.build(uri_parts).to_s}
        log_params(uri.merge!(params.slice(:query, :method, :headers, :body).delete_nils))
      end

      def message_for_excon_response(params)
        log_params(params.slice(:status, :headers, :body))
      end

      def message_for_excon_error(params)
        params[:error].pretty_inspect
      end

      def message_for_other(params)
        log_params(params.except(:instrumentor, :instrumentor_name, :connection, :stack, :middlewares))
      end

      def log_params(params)
        sanitized = sanitize_params(params)
        sanitized[:body] = parse_body(sanitized[:body])
        "\n#{sanitized.pretty_inspect}"
      end

      def parse_body(body)
        JSON.parse(body) if body
      rescue JSON::ParserError
        body
      end

      def sanitize_params(params)
        if params.key?(:headers) && params[:headers].key?('Authorization')
          params[:headers] = params[:headers].dup
          params[:headers]['Authorization'] = "********"
        end
        if params.key?(:password)
          params[:password] = "********"
        end
        if params.key?(:body)
          params[:body] = params[:body].to_s.gsub(/"password":".+?"\}/, '"password":"********"}')
        end
        params
      end
    end
  end
end
