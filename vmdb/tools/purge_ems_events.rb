KEEP_EVENTS  = 6.months
PURGE_WINDOW = 1000

old_logger = $log
$log = VMDBLogger.new(STDOUT)
$log.level = Logger::INFO

begin
  EmsEvent.purge(KEEP_EVENTS.ago.utc, PURGE_WINDOW)
rescue => err
  $log.error("#{err} #{err.backtrace.join("\n")}")
end

$log.close
$log = old_logger
