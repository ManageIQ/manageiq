#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)

KEEP_EVENTS  = 6.months
PURGE_WINDOW = 1000

$log = Vmdb::Loggers.create_logger($stdout)
$log.level = Logger::INFO

begin
  EmsEvent.purge(KEEP_EVENTS.ago.utc, PURGE_WINDOW)
rescue => err
  $log.log_backtrace(err)
end
