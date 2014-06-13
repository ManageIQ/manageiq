class TimeProfile < ActiveRecord::Base
  ALL_DAYS  = (0...7).to_a.freeze
  ALL_HOURS = (0...24).to_a.freeze
  DEFAULT_TZ = "UTC"

  validates_uniqueness_of :description

  serialize :profile
  default_value_for :days,  ALL_DAYS
  default_value_for :hours, ALL_HOURS

  has_many  :miq_reports
  has_many  :metric_rollups

  scope :rollup_daily_metrics, :conditions => {:rollup_daily_metrics => true}

  after_create :rebuild_daily_metrics_on_create
  after_save   :rebuild_daily_metrics_on_save

  def self.find_all_with_entire_tz(*args)
    self.all(*args).select { |tp| tp.entire_tz? }
  end

  def self.all_timezones(*args)
    self.all(*args).collect { |tp| tp.tz }.uniq
  end

  def self.seed
    MiqRegion.my_region.lock do
      utc_tp = default_time_profile

      if utc_tp.nil?
        TimeProfile.create!(
          :description          => DEFAULT_TZ,
          :tz                   => DEFAULT_TZ,
          :rollup_daily_metrics => true
        )
      end
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
    self.hours.include?(ts.in_time_zone(self.tz_or_default(default_tz)).hour)
  end

  def ts_day_in_profile?(ts, default_tz = DEFAULT_TZ)
    ts = Time.parse(ts) if ts.kind_of?(String)
    self.days.include?(ts.in_time_zone(self.tz_or_default(default_tz)).wday)
  end

  def profile
    read_attribute(:profile) || (self.profile = {})
  end

  def tz
    self.profile[:tz]
  end

  def tz=(val)
    self.profile_will_change! if self.profile[:tz] != val
    self.profile[:tz] = val
  end

  def tz_or_default(default_tz = DEFAULT_TZ)
    self.tz || default_tz
  end

  def days
    self.profile[:days]
  end

  def days=(arr)
    arr = arr.collect {|d| d.to_i}
    self.profile_will_change! if self.profile[:days] != arr
    self.profile[:days] = arr
  end

  def hours
    self.profile[:hours]
  end

  def hours=(arr)
    arr = arr.collect {|d| d.to_i}
    self.profile_will_change! if self.profile[:hours] != arr
    self.profile[:hours] = arr
  end

  def entire_tz?
    return self.days.sort == ALL_DAYS && self.hours.sort == ALL_HOURS
  end

  def rebuild_daily_metrics
    oldest_hourly = MetricRollup.first(:select => :timestamp, :conditions => {:capture_interval_name => 'hourly'}, :order => :timestamp)
    self.destroy_metric_rollups
    return if oldest_hourly.nil?

    start_time = [oldest_hourly.timestamp, Metric::Purging.purge_date(:keep_hourly_metrics) || 6.months.ago.utc].max
    end_time   = Time.now.utc
    Metric::Rollup.perf_rollup_gap_queue(start_time, end_time, 'daily', self.id)
  end

  def rebuild_daily_metrics_queue
    MiqQueue.put(
      :class_name  => self.class.name,
      :instance_id => self.id,
      :method_name => 'rebuild_daily_metrics',
      :msg_timeout => 1.hour
    )
  end

  def destroy_metric_rollups
    self.metric_rollups.destroy_all
  end

  def destroy_metric_rollups_queue
    MiqQueue.put(
      :class_name  => self.class.name,
      :instance_id => self.id,
      :method_name => 'destroy_metric_rollups',
      :msg_timeout => 1.hour
    )
  end

  private

  def rebuild_daily_metrics_on_create
    @rebuild_daily_metrics_on_create = true
  end

  def rebuild_daily_metrics_on_save
    if self.rollup_daily_metrics
      self.rebuild_daily_metrics_queue if @rebuild_daily_metrics_on_create || self.changed.include_any?("profile", "rollup_daily_metrics")
    elsif self.changed.include?("rollup_daily_metrics")
      self.destroy_metric_rollups_queue
    end
  ensure
    @rebuild_daily_metrics_on_create = false
  end

  def self.profiles_for_user(user_id, region_id)
    TimeProfile.in_region(region_id).all(
        :conditions => ["(profile_type = ? or (profile_type = ? and  profile_key = ?)) and rollup_daily_metrics = ?",
                        "global", "user", user_id, true],
        :order      => "lower(description) ASC")
  end

  def self.profile_for_user_tz(user_id, user_tz)
    TimeProfile.rollup_daily_metrics.detect { |tp| tp.tz == user_tz && profile_type_for_tz?(tp, user_id) }
  end

  def self.profile_type_for_tz?(tp, user_id)
    tp.profile_type == "global" || (tp.profile_type == "user" && tp.profile_key == user_id)
  end

  def self.default_time_profile
    TimeProfile.rollup_daily_metrics.detect { |tp| tp.tz == DEFAULT_TZ && tp.entire_tz? }
  end
end
