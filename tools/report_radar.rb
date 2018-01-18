#!/usr/bin/env ruby
require File.expand_path("../config/environment", __dir__)
require 'trollop'

opts = Trollop.options(ARGV) do
  banner "USAGE:  #{__FILE__} -h <number of days back to query metrics>\n"

  opt :days, "Days", :short => "d", :type => :int, :default => 1
end

time_range = [opts[:days].days.ago.utc.beginning_of_hour..Time.now.utc.end_of_hour]

OUTPUT_CSV_FILE_PATH = 'cores_usage_per_label.csv'.freeze

HEADERS_AND_COLUMNS = ['Hour', 'Date', 'Label of image (key : value)', 'Project', 'Used Cores'].freeze

CSV.open(OUTPUT_CSV_FILE_PATH, "wb") do |csv|
  csv << HEADERS_AND_COLUMNS

  MetricRollup.where(:timestamp     => time_range,
                     :resource_type => 'CustomAttribute').order(:timestamp).select(:timestamp, :resource_name, :cpu_usage_rate_average, :resource_id, :resource_type).each do |mr|
    date         = mr.timestamp.to_date
    hour         = mr.timestamp.hour
    project_name = mr.resource_name
    label_name   = "#{mr.resource.name}:#{mr.resource.value}"
    csv << [hour, date, label_name, project_name, mr.cpu_usage_rate_average]
  end
end
