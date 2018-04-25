#!/usr/bin/env ruby

RAILS_ROOT = File.expand_path(File.join(__dir__, %w(.. ..)))
require 'manageiq-gems-pending'
require 'miq_logger_processor'

logfile = ARGV.shift if ARGV[0] && File.file?(ARGV[0])
logfile ||= File.join(RAILS_ROOT, "log/evm.log")
logfile = File.expand_path(logfile)

puts "Gathering method calls..."

method_call_hash = MiqLoggerProcessor.new(logfile).each_with_object({}) do |line, hash|
  next unless line.fq_method
  hash[line.fq_method] ||= 0
  hash[line.fq_method] += 1
end

require 'pp'

puts method_call_hash.sort_by { |_key, value| value }.reverse.to_h.pretty_inspect
