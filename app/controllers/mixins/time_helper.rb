module Mixins
  module TimeHelper
    private

    # Create a time in a timezone, return in UTC
    def create_time_in_utc(datetime, tz = nil)                # tz = nil means use user's session timzone
      create_time_in_tz(datetime, tz).in_time_zone("Etc/UTC") # Return the time in UTC
    end

    def create_time_in_tz(datetime, tz = nil)               # tz = nil means use user's session timzone
      if tz && (Time.zone.nil? || tz != Time.zone.name)     # If tz passed in and not default tz
        saved_tz = Time.zone
        Time.zone = tz                                      # Temporarily convert to new tz and create the time object
        t = Time.zone.parse(datetime)                       # Create the time object
        Time.zone = saved_tz                                # Restore original default
      else                                                  # tz not passed in or matches current tz
        t = Time.zone.parse(datetime)                       # Create the time object
      end
      t
    end
  end
end
