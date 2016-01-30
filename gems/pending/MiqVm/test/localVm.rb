require_relative '../../bundler_setup'
require 'ostruct'
require 'log4r'
require 'MiqVm/MiqVm'

class ConsoleFormatter < Log4r::Formatter
  def format(event)
    (event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
  end
end

$log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level => Log4r::DEBUG, :formatter => ConsoleFormatter)
$log.add 'err_console'

VHD = raise "Please define VHD"
diskid    = "ide0:0"
hardware  = "#{diskid}.present = \"TRUE\"\n"
hardware += "#{diskid}.filename = \"#{VHD}\"\n"

begin
  ost = OpenStruct.new
  ost.fileName = VHD
  vm = MiqVm.new(hardware, ost)

  vm.rootTrees.each do |fs|
    puts "*** Found root tree for #{fs.guestOS}"
    puts "Listing files in #{fs.pwd} directory:"
    fs.dirEntries.each { |de| puts "\t#{de}" }
    puts
  end

  CATEGORIES	= %w(accounts services software system)
  CATEGORIES.each do |cat|
    puts "Extracting: #{cat}:"
    xml = vm.extract(cat)
    xml.write($stdout, 4)
    puts
  end

  vm.unmount
rescue => err
  puts err.to_s
  puts err.backtrace.join("\n")
end
