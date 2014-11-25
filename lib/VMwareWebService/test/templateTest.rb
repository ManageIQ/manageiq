$:.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
require 'log4r'
require 'MiqVim'
# require 'MiqVimBroker'

#
# Formatter to output log messages to the console.
#
class ConsoleFormatter < Log4r::Formatter
	def format(event)
		(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end
$vim_log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::INFO, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

TARGET_VM = "rpo-template-test"
vmMor = nil
miqVm = nil

begin
    vim = MiqVim.new(SERVER, USERNAME, PASSWORD)
    
    puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
    puts
    
	miqVm = vim.getVimVmByFilter("config.name" => TARGET_VM)
    
    puts "VM: #{miqVm.name}"
    puts
    
    isTemplate = miqVm.template?
    
    puts "Template: #{isTemplate}"
    if !isTemplate
        puts "Marking VM as Template."
        miqVm.markAsTemplate
        puts "Template: #{miqVm.template?}"
        exit
    end
    
    targetHostObj = vim.hostSystems.values.first
    raise "No suitable target host system found" if !targetHostObj
    
    targetRp = nil
    vim.resourcePoolsByMor.each_value do |rp|
        owner = rp['owner']
        next if !(cr = vim.computeResourcesByMor[owner])
        hosts = cr['host']['ManagedObjectReference']
        hosts = [ hosts ] if !hosts.kind_of?(Array)
        hosts.each do |hmor|
            if hmor == targetHostObj['MOR']
                targetRp = rp
                break
            end
        end
        break if targetRp
    end
    puts
    
    raise "No suitable target resource pool found" if !targetRp
    
    puts "Marking VM as Virtual Machine."
    puts
    miqVm.markAsVm(targetRp, targetHostObj)
    puts "Template: #{miqVm.template?}"
     
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
    puts
    puts "Exiting..."
    miqVm.release if miqVm
    vim.disconnect if vim
end
