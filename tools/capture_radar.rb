#!/usr/bin/env ruby
require File.expand_path("../config/environment", __dir__)
require 'trollop'

opts = Trollop.options(ARGV) do
  banner "USAGE:   #{__FILE__} -h <number of hours back to query metrics>\n" \
         "Example: #{__FILE__} -d <number of days back to query metrics>"

  opt :hours, "Hours", :short => "h", :type => :int, :default => 4
  opt :days,  "Days",  :short => "d", :type => :int
  opt :label, "Label", :short => "l", :type => :string, :default => "com.redhat.component"
end
Trollop.die :hours, "is required" unless opts[:hours] || opts[:days_given]

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

TIME_RANGE = if opts[:days_given]
               [opts[:days].days.ago.utc.beginning_of_hour..Time.now.utc.end_of_hour]
             else
               [opts[:hours].hours.ago.utc.beginning_of_hour..Time.now.utc.end_of_hour]
             end

labels = CustomAttribute.where(:section => ['labels', 'docker_labels'], :resource_type => 'ContainerImage', :name => opts[:label])

# Question - If a container is short lived, will we still be able to find it here?
labels_containers = labels.each_with_object(Hash.new { |h,k| h[k] = [] }) { |l, h| h[l] += l.resource.containers.to_a }

# Group metrics by label/project
labels_metrics = Hash.new { |h,k| h[k] = [] }
labels_containers.each do |l, containers|
  containers.each do |c|
    labels_metrics[[l, c.container_project]] += c.metrics.where(:timestamp => TIME_RANGE).to_a # This should be scoped to time range for the hour
  end
end

# Calculate the max total (of all containers running with the same label/project) CPU cores for each hour of metrics
labels_maxes = Hash.new { |h,k| h[k] = {} }
labels_metrics.each do |label_project, metrics|
  # Group the metrics for this label/project by timestamp so that we can determine the sum of CPU cores usage for
  # each 20 interval and use that for comparing the max usages for the hour
  metrics.group_by { |m| m.timestamp }.each do |ts, metrics|
    hour_ts = ts.beginning_of_hour
    cpu_cores = metrics.map { |m| m.derived_cpu_total_cores_used }.sum

    labels_maxes[label_project][hour_ts] ||= { :cpu_usage_rate_average => 0 }
    labels_maxes[label_project][hour_ts][:cpu_usage_rate_average] = cpu_cores if cpu_cores > labels_maxes[label_project][hour_ts][:cpu_usage_rate_average]
  end
end

# Store the max CPU cores values in metric_rollups
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
    ) if mr.cpu_usage_rate_average < values[:cpu_usage_rate_average]
  end
end
