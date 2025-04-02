#!/usr/bin/env ruby
require "optimist"

VALID_MODES = %w[count purge].freeze
opts = Optimist.options do
  synopsis "Purge orphaned rows from several tables."
  usage "[options]"

  opt :mode, "Mode", :default => "count", :permitted => VALID_MODES
end

purge_mode = opts[:mode].to_sym

# now load rails
require File.expand_path('../config/environment', __dir__)

def purge_by_orphaned(klass, fk, window, purge_mode)
  klass.include PurgingMixin
  klass.define_method(:purge_method) { :destroy }
  klass.purge_by_orphaned(fk, window, purge_mode)
end

CLASSES_TO_PURGE = [
  BinaryBlob,            :resource,           100,
  ContainerCondition,    :container_entity,  1000,
  ContainerEnvVar,       :container,         1000,
  ContainerPortConfig,   :container,         1000,
  ContainerVolume,       :parent,            1000,
  CustomAttribute,       :resource,          1000,
  MiqReportResultDetail, :miq_report_result, 1000,
  RequestLog,            :resource,           500,
  SecurityContext,       :resource,          1000
]

puts "\nNote: Count mode was provided.  No changes are being made.  Use --mode purge to purge the rows.\n" if purge_mode == :count
puts
results = [["Class", purge_mode == :count ? "Orphan Count" : "Purged Rows"]]
_result, bm = Benchmark.realtime_block("TotalTime") do

  CLASSES_TO_PURGE.each_slice(3) do |klass, fk, window|
    Benchmark.realtime_block(klass.name) do
      print "Purging #{klass.name}..."
      purge_by_orphaned(klass, fk, window, purge_mode).tap { |result| results << [klass, result] }
      puts "Done!"
    end
  end
  nil
end
puts "\nResults:\n\n"

puts results.tableize
puts

puts "Timing by class:\n\n"
puts bm.transform_values { |v| v.round(6) }.to_a.unshift(["Model", "Time (s)"]).tableize
