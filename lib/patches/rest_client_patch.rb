require 'restclient/version'
if RestClient::VERSION >= "2.0.0" && RestClient::VERSION <= "2.1.0"
  require 'restclient/request'
  RestClient::Request.module_eval do
    def net_http_object(hostname, port)
      p_uri = proxy_uri

      if p_uri.nil?
        # no proxy set
        Net::HTTP.new(hostname, port)
      elsif !p_uri
        # proxy explicitly set to none
        Net::HTTP.new(hostname, port, nil, nil, nil, nil)
      else
        pass = p_uri.password ? CGI.unescape(p_uri.password) : nil
        user = p_uri.user     ? CGI.unescape(p_uri.user)     : nil
        Net::HTTP.new(hostname, port,
                      p_uri.hostname, p_uri.port, user, pass)

      end
    end
  end
else
  # The above patched method was last modified in 2015 and should be stable in
  # patch releases. With 2.1 or newer, we need verify PR below was included or
  # if this monkey patch needs to change
  # https://github.com/rest-client/rest-client/pull/665
  warn "This RestClient patch for proxy's with percent encoded user/password is for versions ~> 2.0.0.  Please check if this patch is required for version #{RestClient::VERSION}, see: #{__FILE__}"
end
