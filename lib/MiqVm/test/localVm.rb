
$:.push("#{File.dirname(__FILE__)}/..")

require 'rubygems'
require 'ostruct'
require 'log4r'
require 'MiqVm'

class ConsoleFormatter < Log4r::Formatter
	def format(event)
		(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end

toplog = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::INFO, :formatter=>ConsoleFormatter)
toplog.add 'err_console'
$vim_log = $log = toplog if $log.nil?

VMX = "/Users/rpo/Documents/Virtual Machines.localized/Red Hat Enterprise Linux 5.vmwarevm/Red Hat Enterprise Linux 5.vmx"

begin
    ost = OpenStruct.new
    vm = MiqVm.new(VMX, ost)
    
    vm.vmRootTrees.each do | fs |
        puts "*** Found root tree for #{fs.guestOS}"
        puts "Listing files in #{fs.pwd} directory:"
        fs.dirEntries.each { |de| puts "\t#{de}" }
        puts
    end
    
    # wte = "software"
    # puts "Extracting: #{wte}:"
    # xml = vm.extract(wte)
    # xml.write($stdout, 4)
    # puts
    
    vm.unmount
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
end
