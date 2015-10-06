RAILS_ROOT = ENV["RAILS_ENV"] ? Rails.root : File.expand_path(File.join(__dir__, %w(.. ..)))
$:.push File.join(RAILS_ROOT, "gems/pending/util") unless ENV["RAILS_ENV"]
require 'miq_logger_processor'

logfile = ARGV[0] || File.join(RAILS_ROOT, "log/vim.log")

counts = Hash.new { |h, k| h[k] = Hash.new { |h, k| h[k] = [] } }
invalid = {}

t = Time.now
puts "Processing file..."
MiqLoggerProcessor.new(logfile).each do |line|
  next unless line =~ /MiqBrokerObjRegistry\.([^:]+): ([^ ]+) object_id: (\d+)/
  mode, type, object_id = $1, $2, $3
  counts[type][object_id] << mode
end
puts "Processing file...Complete (#{Time.now - t}s)"

puts
puts "Object Counts:"
counts.keys.sort.each do |type|
  object_ids = counts[type]

  incorrect = object_ids.reject { |_object_id, modes| modes.length == 3 && modes.uniq.sort == %w(registerBrokerObj release unregisterBrokerObj) }
  incorrect = incorrect.reject { |_object_id, modes| (c = modes.count('registerBrokerObj')) == modes.count('release') && c == modes.count('unregisterBrokerObj') }
  unreleased, overreleased = incorrect.partition { |_object_id, modes| modes.count('registerBrokerObj') > modes.count('unregisterBrokerObj') }

  invalid[type] = unreleased.transpose[0].sort unless unreleased.empty?

  puts "  #{type}:"
  puts "    Total:         #{object_ids.length}"
  puts "    Unreleased:    #{unreleased.length}"
  puts "    Over-released: #{overreleased.length}"
end

puts
puts "Unreleased object_ids:"
invalid.keys.sort.each do |type|
  puts "  #{type}: #{invalid[type].join(', ')}"
end
