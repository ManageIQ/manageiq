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

ActiveRecord::Base.logger = Logger.new(STDOUT)


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
    mr = label.metric_rollups.find_or_create_by(
        :timestamp => hour_ts,
        :resource_name => project.name,
        :capture_interval_name => "hourly"
    )

    mr.update_attributes(
        :cpu_usage_rate_average => values[:cpu_usage_rate_average]
    ) if mr.cpu_usage_rate_average < values[:cpu_usage_rate_average]
  end
end

# DIFFERENT STRATEGY: USING SQL

def quote(value)
  ActiveRecord::Base.connection.quote(value)
end

def get_hourly_maxes_per_group(label_name)
  sums_query = Metric.where(:resource_type => "Container")
                   .where(:timestamp => TIME_RANGE)
                   .joins("INNER JOIN containers ON metrics.resource_type = 'Container' AND metrics.resource_id = containers.id")
                   .joins("INNER JOIN container_groups ON container_groups.id = containers.container_group_id")
                   .joins("INNER JOIN container_images ON container_images.id = containers.container_image_id")
                   .joins("INNER JOIN custom_attributes ON custom_attributes.name = #{quote(label_name)} AND "\
                    "custom_attributes.resource_type = 'ContainerImage' AND custom_attributes.resource_id = container_images.id")
                   .select("custom_attributes.id as label_id,"\
                    "container_groups.container_project_id as container_project_id, metrics.timestamp as timestamp, "\
                    "sum((metrics.cpu_usage_rate_average * metrics.derived_vm_numvcpus) / 100.0) AS sum_used_cores, "\
                    "count(*) AS containers_in_group")
                   .group("custom_attributes.id, container_groups.container_project_id, metrics.timestamp")
                   .order("container_groups.container_project_id")

  maxes_query = <<-SQL
    WITH sums AS (
      #{sums_query.to_sql}
    )
    SELECT sums.label_id, container_projects.name as container_project_name, date_trunc('hour', sums.timestamp) as hourly_timestamp, max(sums.sum_used_cores) as max_sum_used_cores
      FROM sums
        INNER JOIN container_projects ON container_projects.id = sums.container_project_id
        GROUP BY sums.label_id, container_projects.name, date_trunc('hour', sums.timestamp)
  SQL

  ActiveRecord::Base.connection.execute(maxes_query).to_a
end

results = get_hourly_maxes_per_group('com.redhat.component').sort_by{ |x| [x['hourly_timestamp'], x['label_id'], x['container_project_name']] }

# convert to same structure with same data structure
vintage_maxes = labels_maxes.each_with_object([]) do |(label_project, hours), obj|
  label, project = label_project
  hours.each do |hour_ts, values|
    obj << {"label_id"               => label.id,
            "container_project_name" => project.name,
            "hourly_timestamp"       => hour_ts.to_s,
            "max_sum_used_cores"     => values[:cpu_usage_rate_average]}
  end
end.sort_by{ |x| [x['hourly_timestamp'], x['label_id'], x['container_project_name']] }
