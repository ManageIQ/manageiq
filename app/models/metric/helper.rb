module Metric::Helper
  def self.class_for_interval_name(interval_name, rollup_class = nil)
    interval_name == "realtime" ? Metric : (rollup_class || MetricRollup)
  end

  def self.class_and_association_for_interval_name(interval_name)
    interval_name == "realtime" ? [Metric, :metrics] : [MetricRollup, :metric_rollups]
  end

  def self.find_for_interval_name(interval_name, time_profile_or_tz = nil, rollup_class = nil)
    rel = Metric::Helper.class_for_interval_name(interval_name, rollup_class)
    rel = rel.with_time_profile_or_tz(time_profile_or_tz) if interval_name == 'daily'
    rel.where(:capture_interval_name => interval_name)
  end

  def self.nearest_realtime_timestamp(ts)
    ts = ts.kind_of?(String) ? ts.dup : ts.utc.iso8601
    sec = ts[17, 2]
    return ts if ['00', '20', '40'].include?(sec)

    sec = sec.to_i
    case
    when sec < 20 then ts[17, 2] = '20'
    when sec < 40 then ts[17, 2] = '40'
    else               ts = (Time.parse(ts) + (60 - sec)).iso8601
    end
    ts
  end

  def self.next_realtime_timestamp(ts)
    ts = ts.kind_of?(Time) ? ts.utc : Time.parse(ts).utc
    nearest_realtime_timestamp(ts + 20.seconds)
  end

  def self.nearest_hourly_timestamp(ts)
    ts = ts.kind_of?(Time) ? ts.utc.iso8601 : ts.dup
    ts[14..-1] = "00:00Z"
    ts
  end

  def self.next_hourly_timestamp(ts)
    ts = ts.kind_of?(Time) ? ts.utc : Time.parse(ts).utc
    nearest_hourly_timestamp(ts + 1.hour)
  end

  def self.realtime_timestamps_from_range(start_time, end_time = nil)
    start_time = nearest_realtime_timestamp(start_time)
    return [start_time] if end_time.nil?

    start_time = Time.parse(start_time)
    end_time = Time.parse(nearest_realtime_timestamp(end_time))

    (start_time..end_time).step_value(20.seconds).collect!(&:iso8601)
  end

  def self.hours_from_range(start_time, end_time = nil)
    start_time = nearest_hourly_timestamp(start_time)
    return [start_time] if end_time.nil?

    start_time = Time.parse(start_time)
    end_time = Time.parse(nearest_hourly_timestamp(end_time))

    (start_time..end_time).step_value(1.hour).collect!(&:iso8601)
  end

  def self.nearest_daily_timestamp(ts, tz = nil)
    ts = Time.parse(ts) if ts.kind_of?(String)
    ts = ts.in_time_zone(tz) unless tz.nil?
    ts.beginning_of_day.utc.iso8601
  end

  def self.next_daily_timestamp(ts, tz = nil)
    ts = Time.parse(ts) if ts.kind_of?(String)
    nearest_daily_timestamp(ts + 1.day, tz)
  end

  def self.days_from_range(start_time, end_time = nil, tz = nil)
    start_time = nearest_daily_timestamp(start_time, tz)
    return [start_time] if end_time.nil?

    start_time = Time.parse(start_time)
    end_time = Time.parse(nearest_daily_timestamp(end_time, tz))

    (start_time..end_time).step_value(1.day).collect! { |t| t.in_time_zone(tz).beginning_of_day.utc.iso8601 }
  end

  # @option range :start_date start of the range (if not present, sets to end_date - days)
  # @option range :end_date end of time range (default: now)
  # @option range :days number of days for range (default: 20)
  # @return Range<DateTime,DateTime>
  def self.time_range_from_hash(range)
    return range unless range.kind_of?(Hash)
    end_time = (range[:end_date] || Time.now.utc).utc
    days = range[:days] || 20
    start_time = (range[:start_date] || (end_time - days.days)).utc

    start_time..end_time
  end

  def self.days_from_range_by_time_profile(start_time, end_time = nil)
    TimeProfile.rollup_daily_metrics.each_with_object({}) do |tp, h|
      days = days_from_range(start_time, end_time, tp.tz_or_default)
      days = days.select { |d| tp.ts_day_in_profile?(d) }
      h[tp] = days unless days.empty?
    end
  end

  def self.sanitize_start_end_time(interval, interval_name, start_time, end_time)
    st = case interval_name
         when 'hourly'
           # Alter the start time to be 2 intervals prior the start time requested
           #   due to VIM data integrity issues for most recent historical data
           start_time && (Time.parse(start_time.to_s).utc - (2 * interval.to_i)).utc.iso8601
         else
           start_time.kind_of?(Time) ? start_time.iso8601 : start_time
         end
    et = end_time.kind_of?(Time) ? end_time.iso8601 : end_time

    return st, et
  end

  def self.remove_duplicate_timestamps(recs)
    if recs.respond_to?(:klass) # active record relation
      return recs unless recs.klass <= Metric || recs.klass <= MetricRollup
    elsif recs.empty? || !recs.all? { |r| r.kind_of?(Metric) || r.kind_of?(MetricRollup) }
      return recs
    end

    recs = recs.sort_by { |r| r.resource_type + r.resource_id.to_s + r.timestamp.iso8601 }

    last_rec = nil
    recs.each_with_object([]) do |rec, ret|
      if last_rec &&
         rec.resource_type == last_rec.resource_type &&
         rec.resource_id == last_rec.resource_id && rec.timestamp == last_rec.timestamp
        _log.warn("Multiple rows found for the same timestamp: [#{rec.timestamp}], ids: [#{rec.id}, #{last_rec.id}], resource and id: [#{rec.resource_type}:#{rec.resource_id}]")

        # Merge records with the same timestamp
        last_rec.attribute_names.each { |a| last_rec[a] ||= rec[a] }
      else
        ret << rec
        last_rec = rec
      end
    end
  end

  def self.max_count(counts)
    counts.values.max rescue 0
  end

  def self.get_time_zone(options = nil)
    return TimeProfile::DEFAULT_TZ if options.nil?
    return options[:time_profile].tz if options[:time_profile] && options[:time_profile].tz
    options[:tz] || TimeProfile::DEFAULT_TZ
  end

  # interval_name of daily:
  #   Get yesterday at 23:00 in specified TZ. Then convert that to UTC. Then subtract offsets
  # interval_name of hourly (and others)
  #   Just your typical x.seconds.ago
  #
  # @param start_offset [Integer]
  # @param end_offset [Integer|nil]
  # @return [Range<Datetime,Datetime>] timestamp range for offsets
  def self.time_range_from_offset(interval_name, start_offset, end_offset, tz = nil)
    if interval_name == "daily"
      tz ||= Metric::Helper.get_time_zone
      time_in_tz = Time.now.in_time_zone(tz)
      now = time_in_tz.hour == 23 ? time_in_tz.utc : (time_in_tz.midnight - 1.hour).utc
    else
      now = Time.now.utc
    end

    start_time = now - start_offset.seconds
    end_time   = end_offset.nil? ? now : now - end_offset.seconds

    start_time..end_time
  end

  def self.get_time_interval(obj, timestamp)
    timestamp = Time.parse(timestamp).utc if timestamp.kind_of?(String)

    state = obj.vim_performance_state_for_ts(timestamp)
    start_time = timestamp - state[:capture_interval]

    start_time..timestamp
  end

  def self.latest_metrics(resource_type, since_timestamp, resource_ids = nil)
    metrics = Metric.where(:resource_type => resource_type)
    metrics = metrics.where(:resource_id => resource_ids) if resource_ids
    metrics = metrics.order(:resource_id, :timestamp => :desc)
    metrics = metrics.where('timestamp > ?', since_timestamp)
    metrics.select('DISTINCT ON (metrics.resource_id) metrics.*')
  end
end
