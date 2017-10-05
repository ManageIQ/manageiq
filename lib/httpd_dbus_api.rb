require "faraday"
require "json"

class HttpdDBusApi
  def initialize(options = {})
    @options = options
  end

  def user_attrs(userid, attributes = nil)
    if attributes.present?
      dbus_api("/api/user_attrs/#{userid}?attributes=#{attributes.join(',')}")
    else
      dbus_api("/api/user_attrs/#{userid}")
    end
  end

  def user_groups(userid)
    dbus_api("/api/user_groups/#{userid}")
  end

  private

  def dbus_api(request_url)
    host = ENV["HTTPD_DBUS_API_SERVICE_HOST"]
    port = ENV["HTTPD_DBUS_API_SERVICE_PORT"]
    conn = Faraday.new(:url => "http://#{host}:#{port}") do |faraday|
      faraday.options[:open_timeout] = @options[:open_timeout] || 5  # Net::HTTP open_timeout
      faraday.options[:timeout]      = @options[:timeout]      || 30 # Net::HTTP read_timeout
      faraday.request(:url_encoded)               # form-encode POST params
      faraday.adapter(Faraday.default_adapter)    # make requests with Net::HTTP
    end

    begin
      response = conn.run_request(:get, request_url, nil, nil) do |req|
        req.headers[:content_type] = "application/json"
        req.headers[:accept]       = "application/json"
      end
    rescue => err
      raise("Failed to query the httpd Authentication API service - #{err}")
    end

    if response.body
      body = JSON.parse(response.body.strip)
    end

    raise(body["error"]) if response.status >= 400
    body["result"]
  end
end
