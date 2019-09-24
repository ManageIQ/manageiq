module Metric::Finders
  def self.find_all_by_hour(resource, hour, interval_name)
    start_time, end_time = hour_to_range(hour)
    find_all_by_range(resource, start_time, end_time, interval_name)
  end

  def self.find_all_by_day(resource, day, interval_name, time_profile)
    start_time, end_time = day_to_range(day, time_profile)
    find_all_by_range(resource, start_time, end_time, interval_name)
  end

  def self.hash_by_capture_interval_name_and_timestamp(resource, start_time, end_time, interval_name)
    is_array = resource.kind_of?(Array)
    find_all_by_range(resource, start_time, end_time, interval_name).each_with_object({}) do |p, h|
      if is_array
        h.store_path(p.resource_type, p.resource_id, p.capture_interval_name, p.timestamp.utc.iso8601, p)
      else
        h.store_path(p.capture_interval_name, p.timestamp.utc.iso8601, p)
      end
    end
  end

  def self.find_all_by_range(resource, start_time, end_time, interval_name)
    return [] if resource.blank?
    klass, meth = Metric::Helper.class_and_association_for_interval_name(interval_name)

    if !resource.kind_of?(Array) && !resource.kind_of?(ActiveRecord::Relation)
      scope = resource.send(meth)
    else
      scope = klass.where(:resource => resource)
    end
    scope = scope.where(:capture_interval_name => interval_name) if interval_name != "realtime"
    scope.for_time_range(start_time, end_time)
  end

  #
  # Helper methods
  #

  def self.hour_to_range(hour)
    start_time = hour
    end_time = "#{hour[0..13]}59:59Z"
    return start_time, end_time
  end

  def self.day_to_range(day, time_profile)
    day = Time.parse(day) if day.kind_of?(String)
    day = day.in_time_zone(time_profile.tz_or_default)

    start_time = day.beginning_of_day.utc.iso8601
    end_time   = day.end_of_day.utc.iso8601
    return start_time, end_time
  end
end
