#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)

include ActionDispatch::Routing::UrlFor
include Rails.application.routes.url_helpers

USER_ID       = "admin".freeze
REPORT_PARAMS = {:userid => USER_ID, :mode => "async", :report_source => "Requested by user"}.freeze

def report_from_args
  if ARGV.empty?
    MiqReport.last
  elsif is_numeric?(ARGV[0])
    MiqReport.find_by(:id => ARGV[0])
  else
    MiqReport.find_by(:name => ARGV[0])
  end
end

report = report_from_args
if report.nil?
  puts "Report #{ARGV[0]} doesn't exist"
  exit 1
end

puts "Generating report... #{report.name}"

report.queue_generate_table(:userid => USER_ID)
def report_run
  if defined?(ManageIQPerformance)
    ManageIQPerformance.profile('generate_report') do
      total_report_time = Benchmark.measure { yield }
      puts "Total report time: #{total_report_time.utime} (user)  #{total_report_time.stime} (system)  #{total_report_time.real} (real)  #{total_report_time.total} (total)"
      puts "Total time in SQL: #{Thread.current[:miq_perf_sql_query_data][:queries].inject(0){ |s,r| s + r[:elapsed_time] }.round(2)} ms"
      puts "Total count queries #{Thread.current[:miq_perf_sql_query_data][:total_queries]}"
      slowest_query = Thread.current[:miq_perf_sql_query_data][:queries].max_by{ |x| x[:elapsed_time] }
      puts "Slowest SQL query took #{slowest_query[:elapsed_time]} ms: \n" + slowest_query[:sql]
    end
  else
    yield
  end
end

report_run do
  report._async_generate_table(MiqTask.last.id, REPORT_PARAMS)
end

default_url_options[:host] = "localhost"
default_url_options[:port] = 3000
report_result_id = report.miq_report_results.last.id
report_only_url = url_for(:controller => :report, :action => "report_only", :rr_id => report_result_id)

# open result in browser when Launchy gem is available or display url
defined?(Launchy) ? Launchy.open(report_only_url) : puts(report_only_url)
