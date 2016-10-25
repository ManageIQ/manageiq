class PrivilegeCheckerService

  def valid_session?(session, current_user)
    user_signed_in?(current_user) && session_active?(session) && server_ready?(current_user)
  end

  def user_session_timed_out?(session, current_user)
    user_signed_in?(current_user) && !session_active?(session)
  end

  private

  def user_signed_in?(current_user)
    !!current_user
  end

  def session_active?(session)
    Time.current - (session[:last_trans_time] || Time.current) <= ::Settings.session.timeout
  end

  def server_ready?(current_user)
    current_user.try(:super_admin_user?) || MiqServer.my_server(true).logon_status == :ready
  end
end
