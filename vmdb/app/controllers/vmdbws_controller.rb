require 'actionwebservice'

class VmdbwsController < ApplicationController
  acts_as_web_service
  web_service_api VmdbwsApi
  before_filter :authenticate

  include VmdbwsOps

  protected

  def authenticate
    # require client side cert, so let them through
    return [true, VmdbwsSupport::SYSTEM_USER] if request.headers["SERVER_PORT"] == "8443"

    case get_vmdb_config.fetch_path(:webservices, :integrate, :security)
    when 'none' then return
    else
      # Default to basic authentication
      authenticate_or_request_with_http_basic do |username, password|
        User.authenticate_with_http_basic(username, password)
      end
    end
  end
end
