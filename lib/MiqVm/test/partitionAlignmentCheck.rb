
$:.push("#{File.dirname(__FILE__)}/..")
$:.push("#{File.dirname(__FILE__)}/../../VmwareWebService")

require 'rubygems'
require 'ostruct'
require 'log4r'
require 'MiqVm'
require 'MiqVim'

class ConsoleFormatter < Log4r::Formatter
	def format(event)
		(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end

toplog = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::INFO, :formatter=>ConsoleFormatter)
toplog.add 'err_console'
$vim_log = $log = toplog if $log.nil?

SERVER        = raise "please define SERVER"
USERNAME      = raise "please define USERNAME"
PASSWORD      = raise "please define PASSWORD"
vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

vimVm	= nil
vm		= nil

alignment = 64 * 1024 # Check for alignment on a 64kB boundary

begin
	
	vim.virtualMachinesByMor.values.each do |vmo|
		begin
			vimVm = vim.getVimVmByMor(vmo['MOR'])
    
			vmx = vimVm.dsPath
	    	puts "VM: #{vimVm.name}, VMX = #{vmx}"

			if vimVm.poweredOn?
				puts "\tSkipping running VM"
				puts
				next
			end
    
	    	ost = OpenStruct.new
	    	ost.miqVim = vim
    
			#
			# Given an MiqVm object, we check to see if its partitions are aligned on a given boundary.
			# This boundary is usually based on the logical block size of the underlying storage array;
			# in this example, 64kB.
			#
	    	vm = MiqVm.new(vmx, ost)
	
			#
			# We check all of physical volumes of the VM. This Includes visible and hidden volumes, but excludes logical volumes.
			# The alignment of hidden volumes affects the performance of the logical volumes that are based on them.
			#
			vm.volumeManager.allPhysicalVolumes.each do |pv|
				vmdk = pv.dInfo.filename || pv.dInfo.vixDiskInfo[:fileName]
				aligned = pv.startByteAddr % alignment == 0 ? "Yes" : "No"
				puts "\t#{vmdk}, Partition: #{pv.partNum}, Partition type: #{pv.partType}, LBA: #{pv.lbaStart}, offset: #{pv.startByteAddr}, aligned: #{aligned}"
			end
			
			puts
		ensure
			vimVm.release	if vimVm
			vm.unmount		if vm
			vimVm = vm = nil
		end
	end
    
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
    vim.disconnect	if vim
end
