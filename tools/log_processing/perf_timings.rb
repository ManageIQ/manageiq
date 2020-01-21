#!/usr/bin/env ruby

RAILS_ROOT = File.expand_path(File.join(__dir__, %w(.. ..)))
require 'manageiq-gems-pending'
require 'miq_logger_processor'

logfile = ARGV.shift if ARGV[0] && File.file?(ARGV[0])
logfile ||= File.join(RAILS_ROOT, "log/evm.log")
logfile = File.expand_path(logfile)

$outdir = ARGV.shift if ARGV[0] && File.directory?(ARGV[0])
$outdir ||= File.dirname(logfile)
$outdir.chomp!("/")
$outdir.chomp!("\\")
$outdir = File.expand_path($outdir)

require 'csv'

def dump_csv(type, hashes)
  output = "#{$outdir}/#{type}.csv"
  if hashes.empty?
    puts "No #{type} data points found."
    File.truncate(output, 0) if File.exist?(output)
  else
    puts "#{hashes.length} #{type} data points found."

    keys = hashes[0].keys
    keys.delete_if { |k, _v| [:time, :total_time].include?(k) }
    keys = keys.sort_by(&:to_s)
    keys = keys.unshift(:time)
    keys += [:unaccounted, :total_time]

    graph_data = []
    CSV.open(output, "w") do |csv|
      graph_data << keys[0...-1].collect(&:to_s)
      csv << keys
      hashes.each do |h|
        values = h.values_at(*keys)

        # Calculate unaccounted time
        values[-2] = values[-1].to_f - values[1...-2].inject { |sum, v| sum.to_f + v.to_f }

        graph_data << values[0...-1].collect { |v| v.kind_of?(String) ? v : (v / values[-1] * 100) }
        csv << values
      end
    end

    MiqLoggerProcessor.to_png(graph_data, :outfile => "#{$outdir}/#{type}.png", :title => type.to_s, :graph_type => :stacked)
  end
end

t = Time.now
puts "Processing file..."

all_timings = Hash.new { |k, v| k[v] = [] }
vim_collect_timings = {}

MiqLoggerProcessor.new(logfile).each do |line|
  next unless line =~ /MIQ\((Vm|Host|Storage|EmsCluster|ExtManagementSystem|MiqEnterprise)\.(vim_collect_perf_data|perf_capture_?[a-z]*|perf_process|perf_rollup)\).+Timings:? (\{.+)$/
  target, method, timings = $1, $2, $3

  target.downcase!
  timings = eval(timings)
  key = "#{target}_#{method}".to_sym

  # Handle capture timings which are split over two nearly subsequent lines.
  case method
  when "vim_collect_perf_data"
    timings.delete(:total_time)
    vim_collect_timings[line.pid] = timings
    next
  when "perf_capture"
    unless target == "storage"
      prev_timings = vim_collect_timings.delete(line.pid)
      next if prev_timings.nil?
      timings = prev_timings.merge(timings)
    end

    timings.delete_if { |k, _v| [:start_range, :end_range, :num_vim_queries, :num_vim_trips, :collect_metrics].include?(k) }
  end

  timings[:time] = line.time
  all_timings[key] << timings
end

puts "Processing file...Complete (#{Time.now - t}s)"

puts "Dumping CSVs..."
all_timings.each { |type, hashes| dump_csv(type, hashes) }
puts "Dumping CSVs...Complete"
