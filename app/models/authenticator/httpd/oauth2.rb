module Authenticator
  class Httpd
    module Oauth2
      class Oauth2Error < StandardError; end

      require "net/http"
      require "uri"

      REMOTE_HEADERS =
        {
          "X-REMOTE-USER"           => "preferred_username",
          "X-REMOTE-USER-EMAIL"     => "email",
          "X-REMOTE-USER-FIRSTNAME" => "given_name",
          "X-REMOTE-USER-LASTNAME"  => "family_name",
          "X-REMOTE-USER-FULLNAME"  => "name",
          "X-REMOTE-USER-GROUPS"    => "groups",
          "X-REMOTE-USER-DOMAIN"    => "domain"
        }.freeze

      HTTPD_OPENIDC_CONF = Pathname.new("/etc/httpd/conf.d/manageiq-external-auth-openidc.conf").freeze

      def oidc_configured?
        config[:mode] == "httpd" && config[:provider_type] == "oidc" && config[:oidc_enabled] == true
      end

      def oauth2_token_authenticate(request)
        jwt_token = get_jwt_token_from_headers(request)
        token_info = introspect_jwt_token(jwt_token)
        define_jwt_request_headers(token_info, request)
      rescue => e
        raise Oauth2Error, "Failed to Authenticate with JWT - error #{e}"
      end

      def oauth2_basic_authenticate(username, password, request)
        user_jwt   = get_jwt_token_from_oidc(username, password)
        token_info = introspect_jwt_token(user_jwt)
        define_jwt_request_headers(token_info, request)
      end

      def httpd_oidc_config
        @httpd_oidc_config ||= HTTPD_OPENIDC_CONF.readlines.collect(&:chomp)
      end

      def httpd_oidc_config_param(name)
        param_spec = httpd_oidc_config.find { |line| line =~ /^#{name} .*/i }
        return "" if param_spec.blank?

        param_match = param_spec.match(/^#{name} (.*)/i)
        param_match ? param_match[1].strip : ""
      end

      def oidc_provider_metadata
        @oidc_provider_metadata ||= begin
          oidc_provider_metadata_url = httpd_oidc_config_param("OIDCProviderMetadataURL")
          if oidc_provider_metadata_url.blank?
            {}
          else
            uri = URI.parse(oidc_provider_metadata_url)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = (uri.scheme == "https")
            response = http.request(Net::HTTP::Get.new(uri.request_uri))
            JSON.parse(response.body)
          end
        end
      end

      def oidc_metadata_url_endpoint(oidc_param, metadata_url_key)
        endpoint = httpd_oidc_config_param(oidc_param)
        endpoint = oidc_provider_metadata[metadata_url_key] if endpoint.blank?
        raise Oauth2Error, "Invalid #{HTTPD_OPENIDC_CONF} configuration, missing #{oidc_param} or OIDCProviderMetadataURL #{metadata_url_key} entry" if endpoint.blank?

        endpoint
      end

      def oidc_token_endpoint
        @oidc_token_endpoint ||= oidc_metadata_url_endpoint("OIDCProviderTokenEndpoint", "token_endpoint")
      end

      def oidc_token_introspection_endpoint
        @oidc_token_introspection_endpoint ||= oidc_metadata_url_endpoint("OIDCOAuthIntrospectionEndpoint", "token_introspection_endpoint")
      end

      def oidc_client_id
        @oidc_client_id ||= httpd_oidc_config_param("OIDCClientId")
      end

      def oidc_client_secret
        @oidc_client_secret ||= httpd_oidc_config_param("OIDCClientSecret")
      end

      def oidc_scope
        @oidc_scope ||= httpd_oidc_config_param("OIDCScope")
      end

      def get_jwt_token_from_headers(request)
        jwt_token_match = request.headers["HTTP_AUTHORIZATION"].match(/^Bearer (.*)/)
        jwt_token_match[1] if jwt_token_match
      end

      def get_jwt_token_from_oidc(username, password)
        uri = URI.parse(oidc_token_endpoint)
        request_params = {
          "grant_type" => "password",
          "username"   => username,
          "password"   => password
        }
        request_params["scope"] = oidc_scope if oidc_scope.present?

        post_request = Net::HTTP::Post.new(uri)
        post_request.basic_auth(oidc_client_id, oidc_client_secret)
        post_request.form_data = request_params

        http_params     = {:use_ssl => (uri.scheme == "https")}
        response        = Net::HTTP.start(uri.hostname, uri.port, http_params) { |http| http.request(post_request) }
        parsed_response = JSON.parse(response.body)
        raise Oauth2Error, parsed_response["error_description"] if parsed_response["error"].present?

        parsed_response["access_token"]
      rescue => e
        raise Oauth2Error, "Failed to get a JWT Token for user #{username} - error #{e}"
      end

      def introspect_jwt_token(jwt_token)
        uri = URI.parse(oidc_token_introspection_endpoint)
        request_params = {
          "token" => jwt_token
        }
        request_params["scope"] = oidc_scope if oidc_scope.present?

        post_request = Net::HTTP::Post.new(uri)
        post_request.basic_auth(oidc_client_id, oidc_client_secret)
        post_request.form_data = request_params

        http_params     = {:use_ssl => (uri.scheme == "https")}
        response        = Net::HTTP.start(uri.hostname, uri.port, http_params) { |http| http.request(post_request) }
        parsed_response = JSON.parse(response.body)

        raise Oauth2Error, "Invalid access token, JWT is inactive" if parsed_response["active"] != true

        parsed_response
      rescue => e
        raise Oauth2Error, "Failed to Validate the JWT - error #{e}"
      end

      def define_jwt_request_headers(token_info, request)
        REMOTE_HEADERS.each do |rh, val|
          request.headers[rh] = token_info[val]
        end

        if request.headers["X-REMOTE-USER-GROUPS"].present?
          request.headers["X-REMOTE-USER-GROUPS"] = request.headers["X-REMOTE-USER-GROUPS"].join(",")
        end

        debug_headers(request)
      end

      def debug_headers(request)
        return unless $log.debug?

        REMOTE_HEADERS.keys.each do |rh|
          $audit_log.info("request.headers[#{rh}] ->#{request.headers[rh]}<-")
        end
      end
    end
  end
end
