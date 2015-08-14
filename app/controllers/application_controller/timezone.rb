class ApplicationController
  module Timezone
    extend ActiveSupport::Concern

    included do
      helper_method :get_timezone_abbr, :get_timezone_offset
      helper_method :server_timezone

      hide_action :get_timezone_abbr, :get_timezone_offset
      hide_action :server_timezone
    end

    # return timezone abbreviation
    def get_timezone_abbr(user = nil)
      if user.nil?
        tz = server_timezone
        time = Time.now
      else
        tz = Time.zone
        time = Time.zone.now
      end
      time.in_time_zone(tz).strftime("%Z")
    end

    # returns utc_offset of timezone
    def get_timezone_offset(user = nil, formatted = false)
      tz = user ? user.get_timezone : server_timezone
      tz = ActiveSupport::TimeZone::MAPPING[tz]
      ActiveSupport::TimeZone.all.each do  |a|
        if ActiveSupport::TimeZone::MAPPING[a.name] == tz
          if formatted
            return a.formatted_offset
          else
            return a.utc_offset
          end
        end
      end
    end

    def server_timezone
      MiqServer.my_server.server_timezone
    end
  end
end
