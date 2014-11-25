$:.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
require 'log4r'
require 'MiqVim'
require 'VimTypes'
require 'MiqVimBroker'

#
# Formatter to output log messages to the console.
#
class ConsoleFormatter < Log4r::Formatter
	def format(event)
		(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end
$vim_log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::DEBUG, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

$miq_wiredump = false

$stderr.sync = true
$stdout.sync = true

SRC_TMPL      	= "rpo-clone-src-template"	# Source of the clone
BASE_VM      	= "rpo-clone-src"			# Used to get resource pool 
TARGET_VM   	= "rpo-linked-clone"		# Target of the clone

sVmMor = nil
miqVm = nil

vimDs = nil
dsName = "DEVOpen-E0"

begin
	vim = MiqVim.new(SERVER, USERNAME, PASSWORD)
    
    puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
    puts
    
    #
    # Get the source template.
    #
    miqTmpl		= vim.getVimVmByFilter("config.name" => SRC_TMPL)
	miqBaseVm	= vim.getVimVmByFilter("config.name" => BASE_VM)

	puts "#{SRC_TMPL} vmPathName:      #{miqTmpl.dsPath}"
    
    puts "Template: #{miqTmpl.name}"
    puts

	rpmor = miqBaseVm.vmh['resourcePool']
	puts "Target resource pool: #{rpmor}"
	
	fmor = miqBaseVm.vmh['parent']
	puts "Folder: #{fmor}"
	
	#
	# The source of the clone (VM or Template) must have a snapshot
	# on which to base the linked clone.
	#
	begin
		snapmor = miqTmpl.vmh.snapshot.currentSnapshot
	rescue
		raise "#{SRC_TMPL} must have a current snapshot"
	end
	puts "Current snapshot: #{snapmor}"
	    
    #
    # See if the target VM already exists.
    #
	begin
    	dMiqVm = vim.getVimVmByFilter("config.name" => TARGET_VM)

        puts "Target VM: #{TARGET_VM} already exists"
        puts "\tDeleting #{TARGET_VM}..."
        dMiqVm.destroy
        puts "done."
        exit
	rescue
		# Ignore expectd error
    end

	puts "Preparing to clone: #{SRC_TMPL} to #{TARGET_VM}"

	cspec = VimHash.new('VirtualMachineCloneSpec') do |cs|
	    cs.powerOn          = 'false'
	    cs.template         = 'false'
		cs.snapshot			= snapmor
	    # cs.config			= config
	    # cs.customization	= customization
    	cs.location = VimHash.new('VirtualMachineRelocateSpec') do |csl|
			csl.diskMoveType	= VirtualMachineRelocateDiskMoveOptions::CreateNewChildDiskBacking
			csl.pool			= rpmor
			# csl.datastore		= dsmor
			# csl.host			= hmor
			# csl.disk			= disk
			# csl.transform		= transform
		end
	end
    
    puts
    puts "Cloning..."
	miqTmpl.cloneVM_raw(fmor, TARGET_VM, cspec)
    puts "done."

	exit

	#
    # Get the target VM.
    #
    tvm = vim.virtualMachinesByFilter("config.name" => TARGET_VM)
    if tvm.empty?
        puts "VM: #{TARGET_VM} not found"
        exit
    end

	if (vmp = tvm[0]['summary']['config']['vmPathName'])
		puts "#{TARGET_VM} vmPathName:      #{vmp}"
	else
		puts "#{TARGET_VM} vmPathName is not set"
	end
		
	if (vmlp = tvm[0]['summary']['config']['vmLocalPathName'])
		puts "#{TARGET_VM} vmLocalPathName: #{vmlp}"
	else
		puts "#{TARGET_VM} vmLocalPathName is not set"
	end
	
	exit if !vmp || !vmlp
	
	puts "#{TARGET_VM} not hashed by #{vmp}"  if !vim.virtualMachines[vmp]
	puts "#{TARGET_VM} not hashed by #{vmlp}" if !vim.virtualMachines[vmlp]
    
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
    puts
    puts "Exiting..."
    miqTmpl.release if miqTmpl
	miqBaseVm.release if miqBaseVm
    vim.disconnect if vim
end
