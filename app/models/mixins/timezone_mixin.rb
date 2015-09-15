module TimezoneMixin
  extend ActiveSupport::Concern

  def with_a_timezone(timezone)
    curr_tz = Time.zone
    begin
      Time.zone = timezone
      yield
    ensure
      Time.zone = curr_tz
    end
  end

  def with_current_user_timezone
    timezone = User.current_user.try(:get_timezone) || self.class.server_timezone
    with_a_timezone(timezone) { yield }
  end

  module ClassMethods
    def server_timezone
      MiqServer.my_server.server_timezone
    end
  end
end
