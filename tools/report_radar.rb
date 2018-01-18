#!/usr/bin/env ruby

OUTPUT_CSV_FILE_PATH = 'report_radar.csv'.freeze
HEADERS_AND_COLUMNS = ['Hour', 'Date', 'Label of image (key : value)', 'Project', 'Used Cores'].freeze

require File.expand_path("../config/environment", __dir__)
require 'trollop'

opts = Trollop.options(ARGV) do
  banner "USAGE:  #{__FILE__} -d <number of days back to query metrics, default is 1 day>\n" \
         "        or                                                                     \n" \
         "        #{__FILE__} -s <start date to query metrics, required>                 \n" \
         "        #{__FILE__} -e <end date to query metrics, default is current date>    \n" \

  opt :days, "Days", :short => "d", :type => :int, :default => 1
  opt :start, "Start Date", :short => "s", :type => :int
  opt :end, "End Date", :short => "e", :type => :int
end

def absolute_time_range(start_date, end_date)
  Trollop.die "Start date is missing" if end_date && !start_date

  begin
    end_date = if end_date
                 Date.strptime(end_date.to_s, "%Y%m%d").end_of_day.utc
               else
                 Time.now.end_of_day.utc
               end

    start_date = Date.strptime(start_date.to_s, "%Y%m%d").beginning_of_day.utc
  rescue ArgumentError
    Trollop.die "Cannot parse any of input date"
  end

  if start_date > end_date
    Trollop.die "Start date cannot be greater then end date"
  end

  [start_date..end_date]
end

time_range = if opts[:start] || opts[:end]
               absolute_time_range(opts[:start], opts[:end])
             else
               [opts[:days].days.ago.utc.beginning_of_hour..Time.now.utc.end_of_hour]
             end

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
