require 'actionwebservice'

class VmdbwsController < ApplicationController
  acts_as_web_service
  web_service_api VmdbwsApi
  before_filter :authenticate

  include VmdbwsOps

  protected

  def authenticate
    ws_security = get_vmdb_config.fetch_path(:webservices, :integrate, :security)
    # require client side cert, so let them through
    if request.headers["SERVER_PORT"] == "8443" || ws_security == 'none'
      @username = VmdbwsSupport::SYSTEM_USER
      return true
    end

    # Default to basic authentication
    # Block must return false to fail authentication
    authenticate_or_request_with_http_basic do |username, password|
      authenticate_options = {:require_user => true}

      timeout = get_vmdb_config.fetch_path(:webservices, :authentication_timeout)
      authenticate_options[:timeout] = timeout.to_i_with_method if timeout

      authenticated, @username = User.authenticate_with_http_basic(username, password, request, authenticate_options)
      authenticated
    end
  end
end
