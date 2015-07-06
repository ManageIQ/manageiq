$:.push(File.dirname(__FILE__))
$:.push("#{File.dirname(__FILE__)}/../fs/MiqFS")
$:.push("#{File.dirname(__FILE__)}/../fs/MiqFS/modules")

require 'ostruct'
require 'MiqVm'
require 'MiqFS'
require 'RealFS'

class MiqLocalVm < MiqVm
        
    def initialize
        @ost = OpenStruct.new
        @vmRootTrees = [ MiqFS.new(RealFS, OpenStruct.new) ]
        @volumeManager = OpenStruct.new
        @vmConfigFile = "Local VM"
        @vmDir = ""
		@vmConfig = OpenStruct.new
    end # def initialize
    
    def vmRootTrees
        return @vmRootTrees
    end
    
    def volumeManager
        return @volumeManager
    end
    
    def unmount
		$log.info "MiqLocalVm.unmount called."
    end
    
end # class MiqVm

if __FILE__ == $0
    
    require 'rubygems'
    require 'log4r'
    
    class ConsoleFormatter < Log4r::Formatter
    	def format(event)
    		(event.data.kind_of?(String) ? event.data : event.data.inspect)
    	end
    end

    toplog = Log4r::Logger.new 'toplog'
    Log4r::StderrOutputter.new('err_console', :level=>Log4r::DEBUG, :formatter=>ConsoleFormatter)
    toplog.add 'err_console'
    $log = toplog if $log.nil?
   
	vm = MiqLocalVm.new
    
	["accounts", "services", "software", "system"].each do |cat|
		xml = vm.extract(cat)
		xml.write($stdout, 4)
	end
    
    vm.unmount
    puts "...done"
end
