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

labels = CustomAttribute.where(:name => "com.redhat.component")
# TODO Need to add project to this here
# Question - If a container is short lived, will we still be able to find it here?
labels_containers = labels.each_with_object(Hash.new { |h,k| h[k] = [] }) { |l, h| h[l.value] += l.resource.containers.to_a }

labels_metrics = Hash.new { |h,k| h[k] = [] }
labels_containers.each do |l, containers|
  containers.each do |c| 
    labels_metrics[l] += c.metrics.to_a # This should be scoped to time range for the hour
  end
end

# labels_metrics.each {|l,m| puts "#{l} => #{m.map(&:resource_id).inspect}"}

max_by_label = Hash.new { |h,k| h[k] = {} }
labels_metrics.each do |label, metrics|
  metrics.each do |m|
    hour_ts = m.timestamp.beginning_of_hour
    cpu_cores = m.derived_cpu_total_cores_used
    
    max_by_label[label][hour_ts] ||= 0
    max_by_label[label][hour_ts] = cpu_cores if cpu_cores > max_by_label[label][hour_ts]
  end
end

ap max_by_label["jboss-eap-6-eap64-openshift-docker"]