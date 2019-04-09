#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)
require 'optimist'

include ActionDispatch::Routing::UrlFor
include Rails.application.routes.url_helpers

options = Optimist.options do
  opt :user, "userid", :default => "admin"
  opt :report_name_or_id, "report name or report id", :short => "n", :type => :string
end

# backward compatibility
if ARGV[0].present? && options[:report_name_or_id].nil?
  options[:report_name_or_id] = ARGV[0]
end

REPORT_PARAMS = {:userid => options[:user], :mode => "async", :report_source => "Requested by user"}.freeze

def report_from_args(options)
  if options[:report_name_or_id].nil?
    MiqReport.last
  elsif is_numeric?(options[:report_name_or_id])
    MiqReport.find_by(:id => options[:report_name_or_id])
  else
    MiqReport.find_by(:name => options[:report_name_or_id])
  end
end

report = report_from_args(options)

Optimist.die "Report #{options[:report_name_or_id]} doesn't exist" if report.nil?

puts "Generating report... #{report.name}"

report.queue_generate_table(:userid => options[:user])
report._async_generate_table(MiqTask.last.id, REPORT_PARAMS)

default_url_options[:host] = "localhost"
default_url_options[:port] = 3000
report_result_id = report.miq_report_results.last.id
report_only_url = url_for(:controller => :report, :action => "report_only", :rr_id => report_result_id)

# open result in browser when Launchy gem is available or display url
defined?(Launchy) ? Launchy.open(report_only_url) : puts(report_only_url)
