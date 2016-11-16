module DashboardHelper
  def ext_auth?(auth_option = nil)
    return false unless ::Settings.authentication.mode == 'httpd'
    auth_option ? ::Settings.authentication[auth_option] : true
  end
end
