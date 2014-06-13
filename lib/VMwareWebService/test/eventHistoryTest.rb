$:.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
require 'log4r'
require 'MiqVim'
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
Log4r::StderrOutputter.new('err_console', :level=>Log4r::INFO, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

# $miq_wiredump = true

vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

miqHost = nil

begin
    puts "vim.class: #{vim.class.to_s}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"

	#
	# Don't read events that occur after this time.
	#
	endTime = vim.currentServerTime.to_s

	##
	# Dump all of available events in the event history.
	# This can take a very long time.
	##
	# eventSpec = VimHash.new("EventFilterSpec") do |efs|
	# 	efs.time = VimHash.new("EventFilterSpecByTime") do |eft|
	# 		eft.endTime = endTime
	# 	end
	# 	efs.disableFullMessage = 'true'
	# end
    # miqEh = vim.getVimEventHistory(eventSpec)
    # 
	# p = 0
	# while (events = miqEh.readNext) do
	# 	puts "Events - Page #{p}:"
	# 	vim.dumpObj(events)
	# 	p += 1
	# end
	
	##
	# Dump all the available events of type 'VmCreatedEvent' or 'VmRemovedEvent'
	##
	eventSpec = VimHash.new("EventFilterSpec") do |efs|
		efs.time = VimHash.new("EventFilterSpecByTime") do |eft|
			eft.endTime = endTime
		end
		efs.disableFullMessage = 'false'
		efs['type'] = ['VmCreatedEvent']
	end
	
	miqEh = vim.getVimEventHistory(eventSpec)
	
	#
	# Read events from newest to oldest.
	#
	miqEh.reset
	#
	# It looks like the reset method doesn't position us at the first page.
	# readPrevious returns the second page and readNext returns the first.
	# This readNext is just to position us at the first page. It will return
	# the first page of data and so will the first readPrevious, so we ignore
	# the data returned by readNext.
	#
	events = miqEh.readNext
    
	p = 0
	nevent = 0
	while (events = miqEh.readPrevious) do
		puts "Events - Page #{p}:"
		events.each do |event|
			puts "*** Event: #{event.xsiType}"
			puts "****** #{event.vm.name}"
			#
			# Check to see if the VM is still in the inventory.
			#
			# Match by MOR and VM name, just in case the MOR was reused.
			# This may not be 100% accurate, we may need to add additional checks to ensure we associate
			# the proper VM with the event.
			#
			vm = vim.virtualMachinesByFilter('summary.vm' => event.vm.vm, 'config.name' => event.vm.name).first
			if !vm
				puts "****** VM no longer exists"
			else
				puts "****** VM path: #{vm.summary.config.vmPathName}"
			end
			puts event.createdTime
			nevent += 1
			# vim.dumpObj(event)
			puts
		end
		p += 1
	end
	puts "*** Total events: #{nevent}"
	puts
	
	#
	# Read events from oldest to newest.
	#
	miqEh.rewind
    
	p = 0
	nevent = 0
	while (events = miqEh.readNext) do
		puts "Events - Page #{p}:"
		events.each do |event|
			puts "*** Event: #{event.xsiType}"
			puts "****** #{event.vm.name}"
			#
			# Check to see if the VM is still in the inventory.
			#
			# Match by MOR and VM name, just in case the MOR was reused.
			# This may not be 100% accurate, we may need to add additional checks to ensure we associate
			# the proper VM with the event.
			#
			vm = vim.virtualMachinesByFilter('summary.vm' => event.vm.vm, 'config.name' => event.vm.name).first
			if !vm
				puts "****** VM no longer exists"
			else
				puts "****** VM path: #{vm.summary.config.vmPathName}"
			end
			puts event.createdTime
			nevent += 1
			# vim.dumpObj(event)
			puts
		end
		p += 1
	end
	puts "*** Total events: #{nevent}"

rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
	miqEh.release if miqEh
    vim.disconnect
end
