MODES = %w{count purge}

require 'trollop'
ARGV.shift if ARGV[0] == '--'
opts = Trollop::options do
  banner "Purge metrics records.\n\nUsage: rails runner #{$0} [-- options]\n\nOptions:\n\t"
  opt :mode,     "Mode (#{MODES.join(", ")})", :default => "count"
  opt :realtime, "Realtime range", :default => "4.hours"
  opt :hourly,   "Hourly range",   :default => "6.months"
  opt :daily,    "Daily range",    :default => "6.months"
  opt :window,   "Window of records to delete at once", :default => 1000
end
Trollop::die "script must be run with bin/rails runner" unless Object.const_defined?(:Rails)
Trollop::die :mode,     "must be one of #{MODES.join(", ")}" unless MODES.include?(opts[:mode])
Trollop::die :realtime, "must be a number with method (e.g. 4.hours)"  unless opts[:realtime].number_with_method?
Trollop::die :hourly,   "must be a number with method (e.g. 6.months)" unless opts[:hourly].number_with_method?
Trollop::die :daily,    "must be a number with method (e.g. 6.months)" unless opts[:daily].number_with_method?
Trollop::die :window,   "must be a number grater than 0" if opts[:window] <= 0

def log(msg)
  $log.info "MIQ(#{__FILE__}) #{msg}"
  puts msg
end

formatter = Class.new.extend(ActionView::Helpers::NumberHelper)

log "Purge Counts"
dates = {}
counts = {}
%w{realtime hourly daily}.each do |interval|
  dates[interval]  = opts[interval.to_sym].to_i_with_method.ago.utc
  counts[interval] = Metric::Purging.purge_count(dates[interval], interval)
  log "  #{"#{interval.titleize}:".ljust(9)} #{formatter.number_with_delimiter(counts[interval])}"
end
puts

exit if opts[:mode] != "purge"

log "Purging..."
require 'progressbar'
%w{realtime hourly daily}.each do |interval|
  pbar = ProgressBar.new(interval.titleize, counts[interval])
  Metric::Purging.purge(dates[interval], interval, opts[:window]) { |count, total| pbar.inc count } if counts[interval] > 0
  pbar.finish
end
log "Purging...Complete"
