class PrivilegeCheckerService
  def initialize(vmdb_config = VMDB::Config.new("vmdb").config)
    @vmdb_config = vmdb_config
  end

  def valid_session?(session)
    user_signed_in?(session) && session_active?(session) && server_ready?(session)
  end

  def user_session_timed_out?(session)
    session[:userid] && !session_active?(session)
  end

  private

  def user_signed_in?(session)
    !!session[:userid]
  end

  def session_active?(session)
    Time.current - session[:last_trans_time] <= @vmdb_config[:session][:timeout]
  end

  def server_ready?(session)
    MiqServer.my_server(true).logon_status == :ready || session[:userrole] == "super_administrator"
  end
end
