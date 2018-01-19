#!/usr/bin/env ruby
require File.expand_path("../../config/environment", __dir__)
require 'trollop'
require './tools/radar/rollup_radar_mixin'
include RollupRadarMixin

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
  belongs_to :container, :class_name => "Container", :foreign_type => "Container", :foreign_key => :resource_id
end

ContainerImage
class ContainerImage
  has_many :container_image_labels, -> { where(:section => ['labels', 'docker_labels']) }, :class_name => "CustomAttribute", :as => :resource
end

TIME_RANGE = if opts[:days_given]
               [opts[:days].days.ago.utc.beginning_of_hour..Time.now.utc.end_of_hour]
             else
               [opts[:hours].hours.ago.utc.beginning_of_hour..Time.now.utc.end_of_hour]
             end

get_hourly_maxes_per_group(opts[:label], TIME_RANGE).each do |row|
  resource_names_json = row.without('hourly_timestamp', 'max_sum_used_cores').to_json

  mr = MetricRollup.find_or_create_by(:resource_type         => 'CustomAttribute',
                                      :timestamp             => row['hourly_timestamp'],
                                      :capture_interval_name => "hourly",
                                      :resource_name         => resource_names_json)

  cpu_usage_rate_average = mr.cpu_usage_rate_average || 0
  next unless cpu_usage_rate_average < row['max_sum_used_cores']
  mr.update_attributes(
    :cpu_usage_rate_average => row['max_sum_used_cores']
  )
end
