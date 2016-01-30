$LOAD_PATH.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
require 'rubygems'
require 'log4r'
require 'miq_hyperv_disk'

#
# Formatter to output log messages to the console.
#
class ConsoleFormatter < Log4r::Formatter
  def format(event)
    (event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
  end
end

$log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level => Log4r::DEBUG, :formatter => ConsoleFormatter)
$log.add 'err_console'

HOST = raise "Please define SERVERNAME"
PORT = raise "Please define PORT"
USER = raise "Please define USER"
PASS = raise "Please define PASS"
DISK = raise "Please define DISK"

hyperv_disk = MiqHyperVDisk.new(HOST, USER, PASS, PORT)

$log.debug "Reading 256 byte slices"
hyperv_disk.open(DISK)
hyperv_disk.seek(0)
(1..8).each do |i|
  buffer = hyperv_disk.read(256)
  $log.debug "Buffer #{i}: \n#{buffer}\n"
end
