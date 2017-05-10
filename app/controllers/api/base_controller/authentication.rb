module Api
  class BaseController
    module Authentication
      #
      # REST APIs Authenticator and Redirector
      #
      def require_api_user_or_token
        log_request_initiated
        if request.headers[HttpHeaders::MIQ_TOKEN]
          authenticate_with_system_token(request.headers[HttpHeaders::MIQ_TOKEN])
        elsif request.headers[HttpHeaders::AUTH_TOKEN]
          authenticate_with_user_token(request.headers[HttpHeaders::AUTH_TOKEN])
        else
          authenticate_options = {
            :require_user => true,
            :timeout      => ::Settings.api.authentication_timeout.to_i_with_method
          }

          if (user = authenticate_with_http_basic { |u, p| User.authenticate(u, p, request, authenticate_options) })
            auth_user_obj = userid_to_userobj(user.userid)
            authorize_user_group(auth_user_obj)
            validate_user_identity(auth_user_obj)
            User.current_user = auth_user_obj
          else
            request_http_basic_authentication
          end
        end
        log_api_auth
      end

      def user_settings
        {
          :locale                     => I18n.locale.to_s.sub('-', '_'),
          :asynchronous_notifications => ::Settings.server.asynchronous_notifications,
        }.merge(User.current_user.settings)
      end

      def userid_to_userobj(userid)
        User.lookup_by_identity(userid)
      end

      def authorize_user_group(user_obj)
        group_name = request.headers[HttpHeaders::MIQ_GROUP]
        if group_name.present?
          group_obj = user_obj.miq_groups.find_by(:description => group_name)
          raise AuthenticationError, "Invalid Authorization Group #{group_name} specified" if group_obj.nil?
          user_obj.current_group_by_description = group_name
        end
      end

      def validate_user_identity(user_obj)
        @user_validation_service ||= UserValidationService.new(self)
        missing_feature = @user_validation_service.missing_user_features(user_obj)
        if missing_feature
          raise AuthenticationError, "Invalid User #{user_obj.userid} specified, User's #{missing_feature} is missing"
        end
      end

      private

      def log_api_auth
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

      def api_token_mgr
        Environment.user_token_service.token_mgr('api')
      end

      def authenticate_with_user_token(auth_token)
        if !api_token_mgr.token_valid?(auth_token)
          raise AuthenticationError, "Invalid Authentication Token #{auth_token} specified"
        else
          auth_user_obj = userid_to_userobj(api_token_mgr.token_get_info(auth_token, :userid))

          unless request.headers['X-Auth-Skip-Token-Renewal'] == 'true'
            api_token_mgr.reset_token(auth_token)
          end

          authorize_user_group(auth_user_obj)
          validate_user_identity(auth_user_obj)
          User.current_user = auth_user_obj
        end
      end

      def authenticate_with_system_token(x_miq_token)
        @miq_token_hash = YAML.load(MiqPassword.decrypt(x_miq_token))

        validate_system_token_server(@miq_token_hash[:server_guid])
        validate_system_token_timestamp(@miq_token_hash[:timestamp])

        User.authorize_user(@miq_token_hash[:userid])

        auth_user_obj = userid_to_userobj(@miq_token_hash[:userid])

        authorize_user_group(auth_user_obj)
        validate_user_identity(auth_user_obj)
        User.current_user = auth_user_obj
      rescue => err
        api_log_error("Authentication Failed with System Token\nX-MIQ-Token: #{x_miq_token}\nError: #{err}")
        raise AuthenticationError, "Invalid System Authentication Token specified"
      end

      def validate_system_token_server(server_guid)
        raise "Missing server_guid" if server_guid.blank?
        raise "Invalid server_guid #{server_guid} specified" unless MiqServer.where(:guid => server_guid).exists?
      end

      def validate_system_token_timestamp(timestamp)
        raise "Missing timestamp" if timestamp.blank?
        raise "Invalid timestamp #{timestamp} specified" if 5.minutes.ago.utc > timestamp
      end
    end
  end
end
