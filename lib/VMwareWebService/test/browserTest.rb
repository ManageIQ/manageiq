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

$stdout.sync = true
# $miq_wiredump = true

vimDs = nil

# filePattern = "*rpo-*"
filePattern = nil
# testPath	= "rpo-reg-test"
testPath	= nil
pathOnly	= false
recurse		= true

begin
  vim = MiqVim.new(SERVER, USERNAME, PASSWORD)
    
    puts "vim.class: #{vim.class.to_s}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
    puts

	dsName = vim.dataStores.keys.first
	puts "Datastore: #{dsName}"
    
    vimDs = vim.getVimDataStore(dsName)

	puts "All files matching #{filePattern}:"
    vimDs.dsFileSearch(filePattern, testPath, pathOnly, recurse).each { |f| puts "\t#{f['fullPath']}, size: #{f['fileSize']}, type: #{f.xsiType}" }
        
	if pathOnly
	    puts "VM config files matching #{filePattern}:"
	    vimDs.dsVmConfigFileSearch(filePattern, testPath, pathOnly, recurse).each { |f| puts "\t#{f}" }
	    puts
        
	    puts "VM Disk files matching #{filePattern}:"
	    vimDs.dsVmDiskFileSearch(filePattern, testPath, pathOnly, recurse).each { |f| puts "\t#{f}" }
	    puts
        
	    puts "VM Nvram files matching #{filePattern}:"
	    vimDs.dsVmNvramFileSearch(filePattern, testPath, pathOnly, recurse).each { |f| puts "\t#{f}" }
	    puts
        
	    puts "VM Log files matching #{filePattern}:"
	    vimDs.dsVmLogFileSearch(filePattern, testPath, pathOnly, recurse).each { |f| puts "\t#{f}" }
	    puts
        
	    puts "VM Snapshot files matching #{filePattern}:"
	    vimDs.dsVmSnapshotFileSearch(filePattern, testPath, pathOnly, recurse).each { |f| puts "\t#{f}" }
	    puts
        
	    puts "VM Folder files matching #{filePattern}:"
	    vimDs.dsFolderFileSearch(filePattern, testPath, pathOnly, recurse).each { |f| puts "\t#{f}" }
	    puts
    
	    puts "All files matching #{filePattern}:"
	    vimDs.dsFileSearch(filePattern, testPath, pathOnly, recurse).each { |f| puts "\t#{f}" }
	    puts
	else
	    puts "VM config files matching #{filePattern}:"
	    vimDs.dsVmConfigFileSearch(filePattern, testPath, pathOnly, recurse).each { |f| puts "\t#{f['fullPath']}, size: #{f['fileSize']}" }
	    puts
    
	    puts "VM Disk files matching #{filePattern}:"
	    vimDs.dsVmDiskFileSearch(filePattern, testPath, pathOnly, recurse).each { |f| puts "\t#{f['fullPath']}, size: #{f['fileSize']}" }
	    puts
    
	    puts "VM Nvram files matching #{filePattern}:"
	    vimDs.dsVmNvramFileSearch(filePattern, testPath, pathOnly, recurse).each { |f| puts "\t#{f['fullPath']}, size: #{f['fileSize']}" }
	    puts
    
	    puts "VM Log files matching #{filePattern}:"
	    vimDs.dsVmLogFileSearch(filePattern, testPath, pathOnly, recurse).each { |f| puts "\t#{f['fullPath']}, size: #{f['fileSize']}" }
	    puts
    
	    puts "VM Snapshot files matching #{filePattern}:"
	    vimDs.dsVmSnapshotFileSearch(filePattern, testPath, pathOnly, recurse).each { |f| puts "\t#{f['fullPath']}, size: #{f['fileSize']}" }
	    puts
    
	    puts "VM Folder files matching #{filePattern}:"
	    vimDs.dsFolderFileSearch(filePattern, testPath, pathOnly, recurse).each { |f| puts "\t#{f['fullPath']}, size: #{f['fileSize']}" }
	    puts
    
	    puts "All files matching #{filePattern}:"
	    vimDs.dsFileSearch(filePattern, testPath, pathOnly, recurse).each { |f| puts "\t#{f['fullPath']}, size: #{f['fileSize']}" }
	    puts
	end
    
    # exit
        
    files = vimDs.dsHash
    puts "==============================="
    files.each do |p, fi|
        puts p
        puts "\tType: #{fi['fileType']}"
        puts "\tSize: #{fi['fileSize']}"
        puts "\tMod time: #{fi['modification']}"
        if fi['fileType'] == "FolderFileInfo"
            puts "\t\tDirectory entries:"
            fi['dirEntries'].each { |de| puts "\t\t\t#{de}" }
        end
        puts
    end
    
    # exit

    puts "==============================="
    puts "Mounting file system..."
    fs = vimDs.getFs
    puts "done."

    puts "FS Type: #{fs.fsType}"
    puts "FS Id: #{fs.fsId}"
    puts "Volume name: #{fs.volName}"

    puts
    puts "==============================="
    puts "find:"
    fs.findEach("/") do |fp|
        next if !File.fnmatch("*.vmx", fp)
        dsp = fs.dsPath(fp)
        puts "\t" + fp
        puts "\t\tDS Path: #{dsp}"
        fi = fs.fileInfo(fp)
        puts "\t\tType: #{fi['fileType']}"
        puts "\t\tSize: #{fi['fileSize']}"
        puts "\t\tRegistered: #{vim.virtualMachines[dsp] != nil}"
        puts
    end
rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
    vimDs.release if vimDs
    vim.disconnect
end
