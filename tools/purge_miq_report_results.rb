MODES = %w{count purge}

require 'trollop'
ARGV.shift if ARGV[0] == '--'
opts = Trollop::options do
  banner "Purge miq_report_results records.\n\nUsage: rails runner #{$0} [-- options]\n\nOptions:\n\t"
  opt :mode,      "Mode (#{MODES.join(", ")})",          :default => "count"
  opt :window,    "Window of records to delete at once", :default => 100
  opt :date,      "Range of reports to keep by date (default: VMDB configuration)",     :type => :string
  opt :remaining, "Number of results to keep per report (default: VMDB configuration)", :type => :int
end
Trollop::die "script must be run with bin/rails runner"    unless Object.const_defined?(:Rails)
Trollop::die :mode,   "must be one of #{MODES.join(", ")}" unless MODES.include?(opts[:mode])
Trollop::die :window, "must be a number greater than 0"    if opts[:window] <= 0
if opts[:remaining_given]
  Trollop::die :remaining, "must be a number greater than 0" if opts[:remaining] <= 0
  purge_mode  = :remaining
  purge_value = opts[:remaining]
elsif opts[:date_given]
  Trollop::die :date, "must be a number with method (e.g. 6.months)" unless opts[:date].number_with_method?
  purge_mode  = :date
  purge_value = opts[:date].to_i_with_method.ago.utc
else
  purge_mode, purge_value = MiqReportResult.purge_mode_and_value
end

def log(msg)
  $log.info "MIQ(#{__FILE__}) #{msg}"
  puts msg
end

formatter = Class.new.extend(ActionView::Helpers::NumberHelper)

msg = case purge_mode
when :remaining; "last #{purge_value} results"
when :date;      "[#{purge_value.iso8601}]"
end
log "Executing in #{opts[:mode]} mode for report results older than #{msg}"

count = MiqReportResult.purge_count(purge_mode, purge_value)
log "Purge Count: #{formatter.number_with_delimiter(count)}"
puts

exit if opts[:mode] != "purge"

log "Purging..."
require 'progressbar'
pbar = ProgressBar.new("Purging", count)
MiqReportResult.purge(purge_mode, purge_value, opts[:window]) { |count, total| pbar.inc count } if count > 0
pbar.finish
log "Purging...Complete"
