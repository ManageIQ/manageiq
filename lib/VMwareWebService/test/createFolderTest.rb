$:.push("#{File.dirname(__FILE__)}/..")
$:.push("#{File.dirname(__FILE__)}/../..")

require 'bundler_setup'
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
Log4r::StderrOutputter.new('err_console', :level=>Log4r::OFF, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

SERVER   = ""
USERNAME = ""
PASSWORD = ""

# $miq_wiredump = true
PARENT_FOLDER_NAME	= ""
NEW_FOLDER_NAME		= ""

# broker = MiqVimBroker.new(:client)
# vim = broker.getMiqVim(SERVER, USERNAME, PASSWORD)
vim = MiqVim.new(SERVER, USERNAME, PASSWORD)

begin
	miqFolder = newFolder = nil
	
    puts "vim.class: #{vim.class.to_s}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"

	puts
	miqFolder = vim.getVimFolder(PARENT_FOLDER_NAME)
	puts "Found folder: #{miqFolder.name}"

	puts "Sub-folders before:"
	miqFolder.subFolderMors.each do |sfmor|
		subFolder = vim.getVimFolderByMor(sfmor)
		puts "\t#{subFolder.name}"
	end
		
	puts
	puts "Creating folder: #{NEW_FOLDER_NAME}..."
	nfMor = miqFolder.createFolder(NEW_FOLDER_NAME)
	puts "Folder added."
	
	puts
	puts "New folder MOR: #{nfMor} (#{nfMor.class.name})"
	# Reset cache so we will see the new folder.
	# Only needed if not using the broker.
	vim.resetCache
	newFolder = vim.getVimFolderByMor(nfMor)
	puts "Found new folder: #{newFolder.name}"

	puts
	puts "Sub-folders after:"
	miqFolder.reload # reload folder to update children.
	miqFolder.subFolderMors.each do |sfmor|
		subFolder = vim.getVimFolderByMor(sfmor)
		puts "\t#{subFolder.name}"
	end

rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
	miqFolder.release if miqFolder
	newFolder.release if newFolder
    vim.disconnect
end
