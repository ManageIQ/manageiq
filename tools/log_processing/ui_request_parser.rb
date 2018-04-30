#!/usr/bin/env ruby

RAILS_ROOT = File.expand_path(File.join(__dir__, %w(.. ..)))
require 'manageiq-gems-pending'
require 'miq_logger_processor'

logfile = ARGV.shift if ARGV[0] && File.file?(ARGV[0])
logfile ||= File.join(RAILS_ROOT, "log/production.log")
logfile = File.expand_path(logfile)

puts "Gathering requests..."

request_hash = MiqLoggerProcessor.new(logfile).each_with_object({}) do |line, hash|
  if match = line.match(/Started\s(\w*)\s\"([\/\w\d\.\-]*)\"/)
    action, path = match.captures
    hash[action] ||= {}
    hash[action][path] ||= 0
    hash[action][path] += 1
  elsif match = line[/Processing\sby\s([\d\w\:\.\#\_\-]*)/, 1]
    hash["Method"] ||= {}
    hash["Method"][match] ||= 0
    hash["Method"][match] += 1
  end
end

require 'pp'

request_hash.each do |k, v|
  puts "Action: #{k}"
  puts v.sort_by { |_key, value| value }.reverse.to_h.pretty_inspect
end
