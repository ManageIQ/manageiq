module Api
  class BaseController
    module Proxy
      class Request
        require 'faraday'
        require 'faraday_middleware'

        attr_reader :url
        attr_reader :logger

        attr_reader :request
        attr_reader :request_body
        attr_reader :method
        attr_reader :fullpath
        attr_reader :miq_token

        attr_reader :response

        def initialize(url, logger)
          @url    = url
          @logger = logger
        end

        def proxy_request(req, req_body, method, fullpath, token)
          @request      = req
          @request_body = req_body
          @method       = method
          @fullpath     = fullpath
          @miq_token    = token

          @response     = send_request(create_handle, method, fullpath, token, request_body)
          self
        end

        def response_body
          response && response.body.present? ? JSON.parse(response.body) : {}
        end

        private

        def create_handle
          Faraday.new(:url => url, :ssl => {:verify => false}) do |faraday|
            faraday.request(:url_encoded)
            faraday.response(:logger, logger)
            faraday.use FaradayMiddleware::FollowRedirects, :limit => 3, :standards_compliant => true
            faraday.adapter(Faraday.default_adapter)
          end
        end

        def send_request(handle, method, fullpath, token, request_body)
          logger.info("Proxying request to #{url}#{fullpath} ...")

          api_path = URI.join("https://#{url}", fullpath)

          @response = handle.run_request(method, api_path, nil, nil) do |proxy_request|
            content_type = request.headers[:content_type]
            proxy_request.headers[:content_type] = content_type if content_type

            accept = request.headers[:accept]
            proxy_request.headers[:accept] = accept if accept

            miq_group = request.headers['X-MIQ-Group']
            proxy_request.headers['X-MIQ-Group'] = miq_group if miq_group
            proxy_request.headers['X-MIQ-Token'] = token

            proxy_request.body = request_body.to_json if request_body.present?
          end
        rescue => err
          raise "Failed to send request to #{url} - #{err}"
        end
      end
    end
  end
end
