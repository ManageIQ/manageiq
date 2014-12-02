#
# For testing REST API via Rspec requests
#

require 'bcrypt'

module ApiSpecHelper
  HEADER_ALIASES = {
    "auth_token" => "HTTP_X_AUTH_TOKEN"
  }

  DEF_HEADERS = {
    "Accept" => "application/json"
  }

  API_STATUS = Rack::Utils::HTTP_STATUS_CODES.merge(0 => "Network Connection Error")

  def parse_response
    @code    = last_response.status
    @result  = JSON.parse(last_response.body)
    @success = @code < 400
    @status  = API_STATUS[@code] || (@success ? 200 : 400)
    @message = @result.fetch_path("error", "message").to_s
    @success
  end

  def update_headers(headers)
    HEADER_ALIASES.keys.each do |k|
      if headers.key?(k)
        headers[HEADER_ALIASES[k]] = headers[k]
        headers.delete(k)
      end
    end
    headers.merge(DEF_HEADERS)
  end

  def run_get(url, headers = {})
    get url, {}, update_headers(headers)
    parse_response
  end

  def resources_include_suffix?(resources, key, suffix)
    resources.any? { |r| r.key?(key) && r[key].match("#{suffix}$") }
  end

  def resources_include?(resources, key, value)
    resources.any? { |r| r[key] == value }
  end

  def init_api_spec_env
    MiqRegion.seed
    MiqDatabase.seed
    Vmdb::Application.config.secret_token = MiqDatabase.first.session_secret_token
    @guid, @server, @zone = EvmSpecHelper.create_guid_miq_server_zone

    @cfme = {
      :user_name  => "API User",
      :user       => "api_user_id",
      :password   => "api_user_password",
      :auth_token => "",
      :entrypoint => "/api",
      :auth_url   => "/api/auth",
      :vms_url    => "/api/vms"
    }

    @user = FactoryGirl.create(:user, :userid          => @cfme[:user],
                                      :password_digest => BCrypt::Password.create(@cfme[:password]))
  end
end
