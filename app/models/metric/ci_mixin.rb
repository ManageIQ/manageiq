module Metric::CiMixin
  extend ActiveSupport::Concern

  include_concern 'Capture'
  include_concern 'Processing'
  include_concern 'Rollup'
  include_concern 'Targets'
  include_concern 'StateFinders'
  include_concern 'LongTermAverages'

  included do
    # TODO: Move in creation of has_many relations here from various classes?
    has_many :vim_performance_operating_ranges, :dependent => :destroy, :as => :resource

    Metric::LongTermAverages::AVG_METHODS.each do |vcol|
      virtual_column vcol, :type => :float, :uses => :vim_performance_operating_ranges
    end

    Metric::LongTermAverages::AVG_METHODS_WITHOUT_OVERHEAD.each do |vcol|
      virtual_column vcol, :type => :float, :uses => :vim_performance_operating_ranges
    end

    supports :capture do
      metrics_capture_klass = "#{self.class.parent.name}::MetricsCapture".safe_constantize
      unless metrics_capture_klass&.method_defined?(:perf_collect_metrics)
        unsupported_reason_add(:capture, _('This provider does not support metrics collection'))
      end
    end
  end

  def has_perf_data?
    return @has_perf_data unless @has_perf_data.nil?
    @has_perf_data = associated_metrics('hourly').exists?
  end

  def associated_metrics(interval_name)
    _klass, meth = Metric::Helper.class_and_association_for_interval_name(interval_name)
    send(meth).where(:capture_interval_name => interval_name)
  end

  def last_capture(interval_name = "hourly")
    first_and_last_capture(interval_name).last
  end

  def first_capture(interval_name = "hourly")
    first_and_last_capture(interval_name).first
  end

  def first_and_last_capture(interval_name = "hourly")
    perf = associated_metrics(interval_name)
           .select("MIN(timestamp) AS first_ts, MAX(timestamp) AS last_ts")
           .group(:resource_id)
           .limit(1).to_a
           .first
    perf.nil? ? [] : [
      perf.first_ts.kind_of?(String) ? Time.parse("#{perf.first_ts} UTC") : perf.first_ts,
      perf.last_ts.kind_of?(String) ? Time.parse("#{perf.last_ts} UTC") : perf.last_ts
    ]
  end

  #
  # Perf data calculation methods
  #

  def performances_maintains_value_for_duration?(options)
    _log.info("options: #{options.inspect}")
    raise _("Argument must be an options hash") unless options.kind_of?(Hash)
    column = options[:column]
    value = options[:value].to_f
    duration = options[:duration]
    starting_on = options[:starting_on]
    operator = options[:operator].nil? ? ">" : options[:operator]
    operator = "==" if operator == "="
    trend = options[:trend_direction]
    slope_steepness = options[:slope_steepness].to_f
    percentage = options[:percentage] if options[:percentage]
    interval_name = options[:interval_name] || "realtime"
    _klass, meth = Metric::Helper.class_and_association_for_interval_name(interval_name)
    now = options[:now] || Time.now.utc # for testing only

    # Turn on for the listing of timestamps and values in the debug log
    debug_trace = (options[:debug_trace] == true || options[:debug_trace] == "true")

    raise ":column required" if column.nil?
    raise ":value required" if value.nil?
    raise ":duration required" if duration.nil?
    # TODO: Check for valid operators
    unless percentage.nil? || percentage.kind_of?(Integer) && percentage >= 0 && percentage <= 100
      raise _(":percentage expected integer from 0-100, received: %{number}") % {:number => percentage}
    end

    # Make sure any rails durations (1.day, 1.hour) is truly an int
    duration = duration.to_i

    # TODO: starting_on should retrieved from the yaml: performance, capture, every... which is 50... pad it with ~20% more to make sure we don't miss any
    #
    # This really should be the older of the last time this alert was evaluated or the duration provided seconds ago
    #

    pkey = "#{self.class}:#{id}"
    last_task = MiqTask.where(:identifier => pkey).order("id DESC").first

    default_how_long = (interval_name == "realtime" ? 70.minutes : 28.hours)
    starting_on ||= if last_task
                      # task start time + duration + 1 second
                      start_time = last_task.context_data[:start].to_time
                      (start_time - duration + 1)
                    else
                      (now - default_how_long)
                    end
    # Extend the window one duration back to enable handling overlap - consecutive matches that span the boundary
    # between the current and previous evaluations.
    window_starting_on = starting_on - duration
    _log.info("Reading performance records from: #{window_starting_on} to: #{now}")

    scope = send(meth)
    if Metric.column_names.include?(column.to_s)
      scope = scope.select("capture_interval_name, capture_interval, timestamp, #{column}")
    end

    total_records = scope
                    .where(:capture_interval_name => interval_name)
                    .where(["timestamp >= ? and timestamp < ?", window_starting_on, now])
                    .order("timestamp DESC")

    total_records = total_records.to_a
    return false if total_records.empty?

    # Find the record at or near the starting_on timestamp to determine if we need to handle overlap
    rec_at_start_on = total_records.reverse.detect { |r| r.timestamp >= starting_on }
    return false if rec_at_start_on.nil?
    start_on_idx = total_records.index { |r| r.timestamp == rec_at_start_on.timestamp }
    #
    colvalue = rec_at_start_on.send(column)
    if colvalue && colvalue.send(operator, value)
      # If there is a match at the start_on timestamp then we need to check the records going backwards to find the first one that doesnt match.
      # This will become the new starting point for evaluation.
      _log.info("First record at Index: #{start_on_idx}, ts: #{rec_at_start_on.timestamp} is a match, reading backwards to find first non-matching record")
      first_miss = total_records[start_on_idx..-1].detect(-> { total_records.last }) do |rec|
        colvalue = rec.send(column)
        !(colvalue.nil? ? false : colvalue.send(operator, value))
      end
      first_miss_idx = total_records.index { |r| r.timestamp == first_miss.timestamp }
      _log.info("Found non-matching record: Index: #{first_miss_idx}, ts: #{first_miss.timestamp}, #{column}: #{colvalue}")
      # Adjust the range to the latest ts back to the ts of the first non-matching ts
      total_records = total_records[0..first_miss_idx]
    else
      # No orverlap, adjust the range to the latest ts back to the starting_on ts
      total_records = total_records[0..start_on_idx]
    end

    slope, _yint = VimPerformanceAnalysis.calc_slope_from_data(total_records.dup, :timestamp, column)
    _log.info("[#{total_records.length}] total records found, slope: #{slope}, counter: [#{column}] criteria: #{interval_name} from [#{total_records.last.timestamp}] to [#{now}]")

    # Honor trend direction option by comparing with the calculated slope value
    if trend
      case trend.to_sym
      when :up
        unless slope > 0
          _log.info("Returning false result because slope #{slope} is not trending up")
          return false
        end
      when :down
        unless slope < 0
          _log.info("Returning false result because slope #{slope} is not trending down")
          return false
        end
      when :not_up
        unless slope <= 0
          _log.info("Returning false result because slope #{slope} is trending up")
          return false
        end
      when :not_down
        unless slope >= 0
          _log.info("Returning false result because slope #{slope} is trending down")
          return false
        end
      when :up_more_than
        if slope <= (slope_steepness / Metric::Capture::REALTIME_METRICS_PER_MINUTE)
          _log.info("Returning false result because slope #{slope} is not up more than #{slope_steepness} per minute")
          return false
        end
      when :down_more_than
        if slope >= ((slope_steepness * -1.0) / Metric::Capture::REALTIME_METRICS_PER_MINUTE)
          _log.info("Returning false result because slope #{slope} is not down more than #{slope_steepness} per minute")
          return false
        end
      when :none
      end
    end

    cap_int = total_records[0].capture_interval
    cap_int = (interval_name == "realtime" ? (60 / Metric::Capture::REALTIME_METRICS_PER_MINUTE) : 3600) unless cap_int.kind_of?(Integer)

    # If not using a percent recs_in_window will equal recs_to_match. Otherwise recs_to_match is the percentage of recs_in_window
    recs_in_window = duration / cap_int
    recs_to_match  = percentage.nil? ? recs_in_window : (recs_in_window * (percentage / 100.0)).to_i

    _log.info("Need at least #{recs_to_match} matches out of #{recs_in_window} consecutive records for the duration #{duration}")
    match_history = []
    matches_in_window = 0
    total_records.each_with_index do |rec, i|
      # Slide the window and subtract the oldest match_history value from the matches_in_window once we have looked at recs_in_window records.
      matches_in_window -= match_history[i - recs_in_window] if i > (recs_in_window - 1) && match_history[i - recs_in_window]
      colvalue = rec.send(column)
      res = colvalue && colvalue.send(operator, value)
      match_history[i] = res ? 1 : 0
      if res
        matches_in_window += match_history[i]
        _log.info("Matched?: true,  Index: #{i}, Window start index: #{i - recs_in_window}, matches_in_window: #{matches_in_window}, ts: #{rec.timestamp}, #{column}: #{rec.send(column)}") if debug_trace
        return true if matches_in_window >= recs_to_match
      else
        _log.info("Matched?: false, Index: #{i}, Window start index: #{i - recs_in_window}, matches_in_window: #{matches_in_window}, ts: #{rec.timestamp}, #{column}: #{rec.send(column)}") if debug_trace
      end
    end
    false
  end

  def get_daily_time_profile_in_my_region_from_tz(tz)
    return if tz.nil?
    TimeProfile.in_region(region_id).rollup_daily_metrics.find_all_with_entire_tz.detect { |p| p.tz_or_default == tz }
  end

  def log_target
    "#{self.class.name} name: [#{name}], id: [#{id}]"
  end

  def log_specific_target(target)
    "#{target.class.name} name: [#{target.name}], id: [#{target.id}]"
  end

  def log_specific_targets(targets)
    targets.map { |target| log_specific_target(target) }.join(" | ")
  end
end
