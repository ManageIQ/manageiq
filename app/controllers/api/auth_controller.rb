module Api
  class AuthController < BaseController
    def show
      requester_type = fetch_and_validate_requester_type
      auth_token = Environment.user_token_service.generate_token(@auth_user, requester_type)
      res = {
        :auth_token => auth_token,
        :token_ttl  => api_token_mgr.token_get_info(auth_token, :token_ttl),
        :expires_on => api_token_mgr.token_get_info(auth_token, :expires_on)
      }
      render_resource :auth, res
    end

    def destroy
      api_token_mgr.invalidate_token(@auth_token)

      render_normal_destroy
    end

    private

    def fetch_and_validate_requester_type
      requester_type = params['requester_type'] || 'api'
      Environment.user_token_service.validate_requester_type(requester_type)
      requester_type
    rescue => err
      raise BadRequestError, err.to_s
    end
  end
end
