if ARGV.length != 2
  puts "Usage: rails runner #{$0} start_date end_date"
  puts
  puts "  start_date and end_date must be in iso8601 format (e.g. 2010-02-15T00:00:00Z)."
  exit 1
end
start_date, end_date = *ARGV

def log(msg)
  $log.info "MIQ(#{__FILE__}) #{msg}"
  puts msg
end

log "Queueing metrics capture for [#{start_date}..#{end_date}]..."
Metric::Capture.perf_capture_gap(Time.parse(start_date), Time.parse(end_date))
log "Queueing metrics capture for [#{start_date}..#{end_date}]...Complete"
