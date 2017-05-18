class FixVporTimeProfileIds < ActiveRecord::Migration[5.0]
  class VimPerformanceOperatingRange < ActiveRecord::Base
  end

  class TimeProfile < ActiveRecord::Base
    ALL_DAYS   = (0...7).to_a.freeze
    ALL_HOURS  = (0...24).to_a.freeze
    DEFAULT_TZ = "UTC".freeze

    serialize :profile, Hash

    def self.default
      @default ||= begin
        ar_region_class = ArRegion.anonymous_class_with_ar_region
        region_cond = ar_region_class.region_to_conditions(ar_region_class.my_region_number)

        where(region_cond)
          .where(:rollup_daily_metrics => true)
          .select do |tp|
            tp.profile[:days].try(:sort) == ALL_DAYS &&
              tp.profile[:hours].try(:sort) == ALL_HOURS &&
              tp.profile[:tz] == DEFAULT_TZ
          end
          .first
      end
    end
  end

  def up
    if VimPerformanceOperatingRange.where.not(:time_profile_id => nil).exists?
      # User has already used an old version where TimeProfiles were corrected,
      # so the TimeProfile-less records are invalid and should be deleted
      say_with_time("Removing old VimPerformanceOperatingRanges") do
        VimPerformanceOperatingRange.where(:time_profile_id => nil).delete_all
      end
    elsif TimeProfile.any?
      # User has not used an old version where TimeProfiles were corrected,
      # so the TimeProfile-less records just need to be updated to the default TP
      say_with_time("Updating old VimPerformanceOperatingRanges to the default TimeProfile") do
        VimPerformanceOperatingRange.where(:time_profile_id => nil).update_all(:time_profile_id => TimeProfile.default.id)
      end
    end
  end
end
