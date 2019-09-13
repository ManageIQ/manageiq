#!/usr/bin/env ruby
require File.expand_path("../../config/environment", __dir__)
require 'optimist'
require './tools/radar/rollup_radar_mixin'
include RollupRadarMixin

opts = Optimist.options(ARGV) do
  banner "USAGE:   #{__FILE__} -h <number of hours back to query metrics>\n" \
         "Example: #{__FILE__} -d <number of days back to query metrics>"

  opt :hours, "Hours", :short => "h", :type => :int, :default => 2
  opt :days,  "Days",  :short => "d", :type => :int
  opt :label, "Label", :short => "l", :type => :string, :default => "com.redhat.component"
end
Optimist.die :hours, "is required" unless opts[:hours] || opts[:days_given]

ActiveRecord::Base.logger = Logger.new(STDOUT)

include RollupRadarMixin

TIME_RANGE = if opts[:days_given]
               [opts[:days].days.ago.utc.beginning_of_hour..Time.now.utc.end_of_hour]
             else
               [opts[:hours].hours.ago.utc.beginning_of_hour..Time.now.utc.end_of_hour]
             end

get_hourly_maxes_per_group(opts[:label], TIME_RANGE).each do |row|
  mr = MaxByLabel.find_or_create_by(:timestamp    => row['hourly_timestamp'],
                                    :label_name   => row['label_name'],
                                    :label_value  => row['label_value'],
                                    :project_name => row['container_project_name'])

  cpu_usage_rate_average = mr.cpu_usage_rate_average || 0
  next unless cpu_usage_rate_average < row['max_sum_used_cores']
  mr.update(:cpu_usage_rate_average => row['max_sum_used_cores'])
end
