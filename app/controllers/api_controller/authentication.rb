class ApiController
  module Authentication
    #
    # Action Methods
    #

    def show_auth
      requester_type = fetch_and_validate_requester_type
      auth_token = @api_token_mgr.gen_token(@module,
                                            :userid           => @auth_user,
                                            :token_ttl_config => REQUESTER_TTL_CONFIG[requester_type])
      res = {
        :auth_token => auth_token,
        :token_ttl  => @api_token_mgr.token_get_info(@module, auth_token, :token_ttl),
        :expires_on => @api_token_mgr.token_get_info(@module, auth_token, :expires_on)
      }
      render_resource :auth, res
    end

    #
    # REST APIs Authenticator and Redirector
    #
    def require_api_user_or_token
      log_request_initiated
      @auth_token = @auth_user = nil
      if request.env.key?('HTTP_X_AUTH_TOKEN')
        @auth_token  = request.env['HTTP_X_AUTH_TOKEN']
        if !@api_token_mgr.token_valid?(@module, @auth_token)
          raise AuthenticationError, "Invalid Authentication Token #{@auth_token} specified"
        else
          @auth_user     = @api_token_mgr.token_get_info(@module, @auth_token, :userid)
          @auth_user_obj = userid_to_userobj(@auth_user)
          @api_token_mgr.reset_token(@module, @auth_token)
          authorize_user_group(@auth_user_obj)
          validate_user_identity(@auth_user_obj)
          User.current_user = @auth_user_obj
        end
      else
        authenticate_options = {
          :require_user => true,
          :timeout      => @api_config[:authentication_timeout].to_i_with_method
        }

        if (user = authenticate_with_http_basic { |u, p| User.authenticate(u, p, request, authenticate_options) })
          @auth_user     = user.userid
          @auth_user_obj = userid_to_userobj(@auth_user)
          authorize_user_group(@auth_user_obj)
          validate_user_identity(@auth_user_obj)
          User.current_user = @auth_user_obj
        else
          request_http_basic_authentication
        end
      end
      log_api_auth
    end

    def auth_identity
      user  = @auth_user_obj
      group = user.current_group
      {
        :userid     => user.userid,
        :name       => user.name,
        :user_href  => "#{@req[:api_prefix]}/users/#{user.id}",
        :group      => group.description,
        :group_href => "#{@req[:api_prefix]}/groups/#{group.id}",
        :role       => group.miq_user_role_name,
        :tenant     => group.tenant.name,
        :groups     => user.miq_groups.pluck(:description)
      }
    end

    def userid_to_userobj(userid)
      User.find_by_userid(userid)
    end

    def authorize_user_group(user_obj)
      group_name = request.env['HTTP_X_MIQ_GROUP']
      if group_name.present?
        group_obj = user_obj.miq_groups.find_by_description(group_name)
        raise AuthenticationError, "Invalid Authorization Group #{group_name} specified" if group_obj.nil?
        user_obj.miq_group_description = group_name
      end
    end

    def validate_user_identity(user_obj)
      @user_validation_service ||= UserValidationService.new(self)
      missing_feature = @user_validation_service.missing_user_features(user_obj)
      if missing_feature
        raise AuthenticationError, "Invalid User #{user_obj.userid} specified, User's #{missing_feature} is missing"
      end
    end

    def fetch_and_validate_requester_type
      requester_type = params['requester_type']
      return unless requester_type
      REQUESTER_TTL_CONFIG.fetch(requester_type) do
        requester_types = REQUESTER_TTL_CONFIG.keys.join(', ')
        raise BadRequestError, "Invalid requester_type #{requester_type} specified, valid types are: #{requester_types}"
      end
      requester_type
    end
  end
end
