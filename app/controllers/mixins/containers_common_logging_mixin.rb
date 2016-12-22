module ContainersCommonLoggingMixin
  def launch_common_logging
    record = self.class.model.find_by_id(params[:id])
    ems = record.ext_management_system
    route_name = ems.common_logging_route_name
    logging_route = ContainerRoute.find_by(:name => route_name, :ems_id => ems.id)
    if logging_route
      user_token = SecureRandom.base64(15)
      query_params = {'access_token' => ems.authentication_token,
                      'user_token'   => user_token,
                      'redirect'     => record.common_logging_path}
      url = URI::HTTPS.build(:host  => logging_route.host_name,
                             :path  => '/auth/sso-setup',
                             :query => (query_params.collect{|k,v| k + '=' + v }).join('&'))
      http = Net::HTTP.new(url.hostname, url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      begin
        _res = http.request(Net::HTTP::Get.new(url.request_uri))
      rescue Errno::ECONNREFUSED => _e
        javascript_flash(:text         => _("Cannot access '#{url.hostname}'. " \
                                          "Make sure that the logging route is accessible"),
                          :severity    => :error,
                          :spinner_off => true)
      else
        query_params.delete('access_token')
        url = URI::HTTPS.build(:host  => logging_route.host_name,
                               :path  => '/auth/sso-login',
                               :query => (query_params.collect{|k,v| k + '=' + v }).join('&'))
        javascript_open_window(url.to_s)
      end
    else
      javascript_flash(:text         => _("A route named '#{route_name}' is configured to connect to the " \
                                          "common_logging server but it doesn't exist"),
                        :severity    => :error,
                        :spinner_off => true)
    end
  end
end
