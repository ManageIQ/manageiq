
$:.push("#{File.dirname(__FILE__)}/..")
$:.push("#{File.dirname(__FILE__)}/../..")
$:.push("#{File.dirname(__FILE__)}/../../disk")

require 'bundler_setup'
require 'ostruct'
require 'log4r'

require 'disk/MiqDisk'
require 'VolumeManager/MiqVolumeManager'

class ConsoleFormatter < Log4r::Formatter
  def format(event)
    (event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
  end
end

toplog = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::DEBUG, :formatter=>ConsoleFormatter)
toplog.add 'err_console'
$vim_log = $log = toplog if $log.nil?

begin

  volMgr = MiqVolumeManager.fromNativePvs

  puts
  puts "Volume Groups:"
  volMgr.vgHash.each do |vgName, vgObj|
    puts "\t#{vgName}: seq# = #{vgObj.seqNo}"
  end

  puts
  puts "Logical Volumes:"
  volMgr.lvHash.each do |key, lv|
    puts "\t#{key}\t#{lv.dInfo.lvObj.lvName}"
  end

  volMgr.closeAll
  
rescue  => err
  puts err.to_s
  puts err.backtrace.join("\n")
end
