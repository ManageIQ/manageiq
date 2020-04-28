class TimeProfile < ApplicationRecord
  ALL_DAYS  = (0...7).to_a.freeze
  ALL_HOURS = (0...24).to_a.freeze
  DEFAULT_TZ = "UTC"

  serialize :profile
  default_value_for :days,  ALL_DAYS
  default_value_for :hours, ALL_HOURS

  has_many  :miq_reports
  has_many  :metric_rollups

  scope :rollup_daily_metrics, -> { where(:rollup_daily_metrics => true) }

  after_create :rebuild_daily_metrics_on_create
  after_save   :rebuild_daily_metrics_on_save

  def self.find_all_with_entire_tz
    all.select(&:entire_tz?)
  end

  def self.all_timezones
    select(%w(id profile)).collect(&:tz).uniq
  end

  def self.seed
    default_time_profile || create!(
      :description          => DEFAULT_TZ,
      :tz                   => DEFAULT_TZ,
      :profile_type         => "global",
      :rollup_daily_metrics => true) do |_|
      _log.info("Creating global time profile")
    end
  end

  def global?
    profile_type == "global"
  end

  def ts_in_profile?(ts, default_tz = DEFAULT_TZ)
    ts = Time.parse(ts) if ts.kind_of?(String)
    self.ts_day_in_profile?(ts, default_tz) && self.ts_hour_in_profile?(ts, default_tz)
  end

  def ts_hour_in_profile?(ts, default_tz = DEFAULT_TZ)
    ts = Time.parse(ts) if ts.kind_of?(String)
    hours.include?(ts.in_time_zone(tz_or_default(default_tz)).hour)
  end

  def ts_day_in_profile?(ts, default_tz = DEFAULT_TZ)
    ts = Time.parse(ts) if ts.kind_of?(String)
    days.include?(ts.in_time_zone(tz_or_default(default_tz)).wday)
  end

  def profile
    read_attribute(:profile) || (self.profile = {})
  end

  def tz
    profile[:tz]
  end

  def tz=(val)
    self.profile_will_change! if profile[:tz] != val
    profile[:tz] = val
  end

  def tz_or_default(default_tz = DEFAULT_TZ)
    tz || default_tz
  end

  def days
    profile[:days]
  end

  def days=(arr)
    arr = arr.collect(&:to_i)
    self.profile_will_change! if profile[:days] != arr
    profile[:days] = arr
  end

  def hours
    profile[:hours]
  end

  def hours=(arr)
    arr = arr.collect(&:to_i)
    self.profile_will_change! if profile[:hours] != arr
    profile[:hours] = arr
  end

  def entire_tz?
    days.sort == ALL_DAYS && hours.sort == ALL_HOURS
  end

  def default?
    entire_tz? && tz_or_default == DEFAULT_TZ
  end

  def rebuild_daily_metrics
    oldest_hourly = MetricRollup.select(:timestamp).where(:capture_interval_name => "hourly").order(:timestamp).first
    destroy_metric_rollups
    return if oldest_hourly.nil?

    start_time = [oldest_hourly.timestamp, Metric::Purging.purge_date(:keep_hourly_metrics) || 6.months.ago.utc].max
    end_time   = Time.now.utc
    Metric::Rollup.perf_rollup_gap_queue(start_time, end_time, 'daily', id)
  end

  def rebuild_daily_metrics_queue
    MiqQueue.put(
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => 'rebuild_daily_metrics',
      :msg_timeout => 1.hour
    )
  end

  def destroy_metric_rollups
    metric_rollups.destroy_all
  end

  def destroy_metric_rollups_queue
    MiqQueue.put(
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => 'destroy_metric_rollups',
      :msg_timeout => 1.hour
    )
  end

  # Support for multi-region DB. We need to try to find a time profile in each
  # region that matches the selected profile to ensure that we get results for
  # all the regions in the database. We only want one match from each region
  # otherwise we'll end up with duplicate daily rows.
  def profile_for_each_region
    if rollup_daily_metrics
      TimeProfile.rollup_daily_metrics.select { |p| p.profile == profile }
        .group_by(&:region_id).values.map(&:first)
    else
      TimeProfile.none
    end
  end

  def match_user_tz?(user_id, user_tz)
    user_id = user_id.to_s
    tz == user_tz &&
      (profile_type == "global" ||
        (profile_type == "user" && profile_key == user_id))
  end

  private

  def rebuild_daily_metrics_on_create
    @rebuild_daily_metrics_on_create = true
  end

  def rebuild_daily_metrics_on_save
    if rollup_daily_metrics
      rebuild_daily_metrics_queue if @rebuild_daily_metrics_on_create || saved_change_to_profile? || saved_change_to_rollup_daily_metrics?
    elsif saved_change_to_rollup_daily_metrics?
      destroy_metric_rollups_queue
    end
  ensure
    @rebuild_daily_metrics_on_create = false
  end

  # TODO: use AR "or" here
  def self.for_user(user_id)
    where("profile_type = ? or (profile_type = ? and profile_key = ?)", "global", "user", user_id)
  end

  def self.ordered_by_desc
    order(Arel.sql("lower(description) ASC"))
  end

  def self.profiles_for_user(user_id, region_id)
    in_region(region_id)
      .for_user(user_id)
      .rollup_daily_metrics
      .ordered_by_desc
  end

  def self.profile_for_user_tz(user_id, user_tz)
    TimeProfile.rollup_daily_metrics.detect { |tp| tp.match_user_tz?(user_id, user_tz) }
  end

  # @param tz [nil|TimeProfile|TimeZone] (default timezone "UTC")
  # @return [TimeProfile] time profile that uses this time zone
  def self.default_time_profile(tz = DEFAULT_TZ)
    return tz if tz.kind_of?(TimeProfile)
    tz ||= DEFAULT_TZ
    rollup_daily_metrics.find_all_with_entire_tz.detect { |tp| tp.tz_or_default == tz }
  end
end
