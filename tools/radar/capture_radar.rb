#!/usr/bin/env ruby
require File.expand_path("../../config/environment", __dir__)
require 'trollop'

opts = Trollop.options(ARGV) do
  banner "USAGE:   #{__FILE__} -h <number of hours back to query metrics>\n" \
         "Example: #{__FILE__} -d <number of days back to query metrics>"

  opt :hours, "Hours", :short => "h", :type => :int, :default => 2
  opt :days,  "Days",  :short => "d", :type => :int
  opt :label, "Label", :short => "l", :type => :string, :default => "com.redhat.component"
end
Trollop.die :hours, "is required" unless opts[:hours] || opts[:days_given]

ActiveRecord::Base.logger = Logger.new(STDOUT)

capture_last = opts[:days_given] ? opts[:days].days : opts[:hours].hours
Radar.capture(capture_last, opts[:label])
