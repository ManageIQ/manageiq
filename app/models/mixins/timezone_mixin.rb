module TimezoneMixin
  extend ActiveSupport::Concern

  def with_a_timezone(timezone)
    curr_tz = Time.zone # Save current time zone setting
    Time.zone = timezone

    result = yield

    Time.zone = curr_tz # Restore current time zone setting

    return result
  end

  def with_current_user_timezone
    timezone = User.current_user.try(:get_timezone) || self.class.server_timezone
    self.with_a_timezone(timezone) { yield }
  end

  module ClassMethods
    def server_timezone
      MiqServer.my_server.get_config("vmdb").config.fetch_path(:server, :timezone) || "UTC"
    end
  end
end
