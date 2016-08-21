module ContainersCommonLoggingMixin
  def launch_common_logging
    record = self.class.model.find_by_id(params[:id])
    ems = record.ext_management_system
    route_name = ems.common_logging_route_name
    logging_route = ContainerRoute.find_by(:name => route_name, :ems_id => ems.id)
    if logging_route
      url = URI::HTTPS.build(:host => logging_route.host_name,
                             :path => '/auth/token',)
      javascript_open_window_with_post(url.to_s,
                                       'access_token' => ems.authentication_token,
                                       'redirect'     => record.common_logging_path,
                                      )
    else
      render_flash_and_stop_sparkle(_("A route named '#{route_name}' is configured to connect to the " \
                                      "common_logging server but it doesn't exist"), :error)
    end
  end
end
