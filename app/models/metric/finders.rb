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

    cond = Metric::Helper.range_to_condition(start_time, end_time)
    if interval_name != "realtime"
      cond[0] << " AND capture_interval_name = ?"
      cond << interval_name
    end

    if !resource.kind_of?(Array) && !resource.kind_of?(ActiveRecord::Relation)
      scope = resource.send(meth)
    else
      # Group the resources by type to find the ids on which to query
      res_cond = []
      res_params = []
      res_by_type = {}
      resource.each { |r| (res_by_type[r.class.base_class.to_s] ||= []) << r.id }
      res_by_type.each do |t, id|
        res_cond << '(resource_type = ? AND resource_id IN (?))'
        res_params << t << id
      end
      res_cond = res_cond.join(' OR ')

      cond.nil? ? cond = [res_cond] : cond[0] << " AND #{res_cond}"
      cond += res_params

      scope = klass
    end
    scope.where(cond)
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
