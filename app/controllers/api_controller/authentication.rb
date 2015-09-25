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
      @auth_token = @auth_user = nil
      if request.env.key?('HTTP_X_AUTH_TOKEN')
        @auth_token  = request.env['HTTP_X_AUTH_TOKEN']
        if !@api_token_mgr.token_valid?(@module, @auth_token)
          raise AuthenticationError, "Invalid Authentication Token #{@auth_token} specified"
        else
          @auth_user     = @api_token_mgr.token_get_info(@module, @auth_token, :userid)
          @auth_user_obj = userid_to_userobj(@auth_user)
          @api_token_mgr.reset_token(@module, @auth_token)
        end
      else
        authenticate_options = {
          :require_user => true,
          :timeout      => @api_config[:authentication_timeout].to_i_with_method
        }

        if (user = authenticate_with_http_basic { |u, p| User.authenticate(u, p, request, authenticate_options) })
          @auth_user     = user.userid
          @auth_user_obj = userid_to_userobj(@auth_user)
        else
          request_http_basic_authentication
        end
      end
    end

    def userid_to_userobj(userid)
      User.find_by_userid(userid)
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
