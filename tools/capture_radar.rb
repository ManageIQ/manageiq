Metric
class Metric
  def derived_cpu_total_cores_used
    return if cpu_usage_rate_average.nil? || derived_vm_numvcpus.nil? || derived_vm_numvcpus == 0
    (cpu_usage_rate_average * derived_vm_numvcpus) / 100.0
  end
end

CustomAttribute
class CustomAttribute
  has_many   :metric_rollups, :as => :resource
end

TIME_RANGE = [(Time.now - 3.month).beginning_of_hour..Time.now.beginning_of_hour]

labels = CustomAttribute.where(:name => "com.redhat.component")

# Question - If a container is short lived, will we still be able to find it here?
labels_containers = labels.each_with_object(Hash.new { |h,k| h[k] = [] }) { |l, h| h[l] += l.resource.containers.to_a }

labels_metrics = Hash.new { |h,k| h[k] = [] }
labels_containers.each do |l, containers|
  containers.each do |c|
    labels_metrics[[l, c.container_project]] += c.metrics.where(:timestamp => TIME_RANGE).to_a # This should be scoped to time range for the hour
  end
end

labels_maxes = Hash.new { |h,k| h[k] = {} }
labels_metrics.each do |label_project, metrics|
  metrics.each do |m|
    hour_ts = m.timestamp.beginning_of_hour
    cpu_cores = m.derived_cpu_total_cores_used

    labels_maxes[label_project][hour_ts] ||= { :cpu_usage_rate_average => 0 }
    labels_maxes[label_project][hour_ts][:cpu_usage_rate_average] = cpu_cores if cpu_cores > labels_maxes[label_project][hour_ts][:cpu_usage_rate_average]
  end
end

labels_maxes.each do |label_project, hours|
  label, project = label_project
  hours.each do |hour_ts, values|
    mr = label.metric_rollups.find_or_initialize_by(
      :timestamp => hour_ts,
      :resource_name => project.name,
      :capture_interval_name => "hourly"
    )

    mr.update_attributes(
      :cpu_usage_rate_average => values[:cpu_usage_rate_average]
    )
  end
end
