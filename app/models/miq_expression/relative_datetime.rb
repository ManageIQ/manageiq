class MiqExpression::RelativeDatetime
  def self.beginning_or_end_of_hour(ts, mode)
    ts_str = ts.iso8601
    ts_str[14..18] = mode == "end" ? "59:59.999999" : "00:00"
    Time.parse(ts_str)
  end

  def self.relative?(value)
    v = value.downcase
    v.starts_with?("this", "last") || v.ends_with?("ago") || ["today", "yesterday", "now"].include?(v)
  end

  def self.normalize(rel_time, tz, mode = "beginning")
    # time_spec =
    #   <value> <interval> Ago
    #   "Today"
    #   "Yesterday"
    #   "Now"
    #   "Last Week"
    #   "Last Month"
    #   "Last Quarter"
    #   "This Week"
    #   "This Month"
    #   "This Quarter"

    rt = rel_time.downcase

    if rt.starts_with?("this", "last")
      # Convert these into the time spec form: <value> <interval> Ago
      value, interval = rt.split
      rt = "#{value == "this" ? 0 : 1} #{interval} ago"
    end

    if rt.ends_with?("ago")
      # Time spec <value> <interval> Ago
      value, interval, ago = rt.split
      interval = interval.pluralize

      if interval == "hours"
        beginning_or_end_of_hour(value.to_i.hours.ago.in_time_zone(tz), mode)
      elsif interval == "quarters"
        ts = Time.now.in_time_zone(tz).beginning_of_quarter
        (ts - (value.to_i * 3.months)).send("#{mode}_of_quarter")
      else
        value.to_i.send(interval).ago.in_time_zone(tz).send("#{mode}_of_#{interval.singularize}")
      end
    elsif rt == "today"
      Time.now.in_time_zone(tz).send("#{mode}_of_day")
    elsif rt == "yesterday"
      1.day.ago.in_time_zone(tz).send("#{mode}_of_day")
    elsif rt == "now"
      beginning_or_end_of_hour(Time.now.in_time_zone(tz), mode)
    else
      # Assume it's an absolute date or time
      value_is_date = !rel_time.include?(":")
      ts = Time.use_zone(tz) { Time.zone.parse(rel_time) }
      ts = ts.send("#{mode}_of_day") if mode && value_is_date
      ts
    end
  end
end
