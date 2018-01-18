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

ActiveRecord::Base.logger = Logger.new(STDOUT)

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
                     .select("custom_attributes.name as label_name, custom_attributes.value as label_value,"\
                      "container_groups.container_project_id as container_project_id, metrics.timestamp as timestamp, "\
                      "sum((metrics.cpu_usage_rate_average * metrics.derived_vm_numvcpus) / 100.0) AS sum_used_cores, "\
                      "count(*) AS containers_in_group")
                     .group("custom_attributes.name, custom_attributes.value, container_groups.container_project_id, metrics.timestamp")
                     .order("container_groups.container_project_id")

  maxes_query = <<-SQL
    WITH sums AS (
      #{sums_query.to_sql}
    )
    SELECT sums.label_name, sums.label_value, container_projects.name as container_project_name, date_trunc('hour', sums.timestamp) as hourly_timestamp, max(sums.sum_used_cores) as max_sum_used_cores
      FROM sums
        INNER JOIN container_projects ON container_projects.id = sums.container_project_id
        GROUP BY sums.label_name, sums.label_value, container_projects.name, date_trunc('hour', sums.timestamp)
  SQL

  ActiveRecord::Base.connection.execute(maxes_query).to_a
end

get_hourly_maxes_per_group(opts[:label]).each do |row|
  resource_names_json = row.without('hourly_timestamp', 'max_sum_used_cores').to_json

  mr = MetricRollup.find_or_create_by(:resource_type         => 'CustomAttribute',
                                      :timestamp             => row['hourly_timestamp'],
                                      :capture_interval_name => "hourly",
                                      :resource_name         => resource_names_json)

  cpu_usage_rate_average = mr.cpu_usage_rate_average || 0
  mr.update_attributes(
      :cpu_usage_rate_average => row['max_sum_used_cores']
  ) if cpu_usage_rate_average < row['max_sum_used_cores']
end

