module AuthHelper
  def http_login(username = 'username', password = 'password')
    request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(username, password)
  end

  def login_as(user)
    User.stub(:current_user => user)
    User.stub(:current_userid => user.userid)
    session[:userid]   = user.userid
    session[:group]    = user.current_group.try(:id)
    user
  end
end

module AuthRequestHelper
  #
  # pass the @env along with your request, eg:
  #
  # GET '/labels', {}, @env
  #
  def http_login(username = 'username', password = 'password')
    @env ||= {}
    @env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(username, password)
  end
end
