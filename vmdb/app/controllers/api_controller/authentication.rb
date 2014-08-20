class ApiController
  module Authentication
    #
    # Action Methods
    #

    def show_auth
      auth_token = @api_token_mgr.gen_token(@module, :userid => @auth_user)
      res = {
        :auth_token => auth_token,
        :expires_on => @api_token_mgr.token_get_info(@module, auth_token, :expires_on)
      }
      render_resource :auth, res
    end

    #
    # Supporting Methods
    #

    def auth_token_cleanup
      @api_token_mgr.token_cleanup if defined?(@api_token_mgr)
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
        elsif @api_token_mgr.token_expired?(@module, @auth_token)
          raise AuthenticationError, "Authentication Token #{@auth_token} specified expired"
        else
          @auth_user     = @api_token_mgr.token_get_info(@module, @auth_token, :userid)
          @auth_user_obj = userid_to_userobj(@auth_user)
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
  end
end
