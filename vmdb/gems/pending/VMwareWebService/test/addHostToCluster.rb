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
Log4r::StderrOutputter.new('err_console', :level=>Log4r::OFF, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

# $miq_wiredump = true
TARGET_HOST		= raise "please define"
HOST_USERNAME	= ""
HOST_PASSWORD	= ""
CLUSTER_NAME	= ""

miqCluster	= nil
miqHost		= nil

broker = MiqVimBroker.new(:client)
vim = MiqVim.new(SERVER, USERNAME, PASSWORD)
hvim = nil

begin
	
	puts
	puts "VC:"
    puts "vim.class: #{vim.class}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"

	puts
	puts "Clusters: #{vim.clusterComputeResources.keys.join(', ')}"
	miqCluster = vim.getVimCluster(CLUSTER_NAME)
	puts "Found cluster: #{miqCluster.name}"
	
	#
	# Ensure host is in Maintenance Mode before adding it to cluster.
	#
	hvim = MiqVim.new(TARGET_HOST, HOST_USERNAME, HOST_PASSWORD)
	hostMor = hvim.hostSystemsByMor.values.first['MOR']
	miqHost = hvim.getVimHostByMor(hostMor)
	if miqHost.inMaintenanceMode?
		puts "New host is already Maintenance Mode"
	else
		puts "Putting host in Maintenance Mode..."
		miqHost.enterMaintenanceMode
	end
	hvim.disconnect
	hvim = nil
	
	puts
	puts "Adding host: #{TARGET_HOST}..."
	begin
		newHostMor = miqCluster.addHost(TARGET_HOST, HOST_USERNAME, HOST_PASSWORD)
	rescue VimFault => verr
		raise unless (fault = verr.vimFaultInfo.fault)
		raise unless fault.xsiType == "SSLVerifyFault"
		
		sslTp = fault.thumbprint
		puts "VimFault: SSLVerifyFault, thumbprint = #{sslTp}"
		puts "\tRetrying with sslThumbprint..."
		newHostMor = miqCluster.addHost(TARGET_HOST, HOST_USERNAME, HOST_PASSWORD, :sslThumbprint => sslTp)
	end
	puts "Host added."
	
	puts
	puts "New host MOR: #{newHostMor}"
	
	#
	# This will only work when connecting through the broker.
	#
	miqHost = vim.getVimHostByMor(newHostMor)
	puts "Got object for new host: #{miqHost.name}"
	
	if miqHost.inMaintenanceMode?
		puts "New host is in Maintenance Mode"
		puts "\texiting Maintenance Mode..."
		miqHost.exitMaintenanceMode
		puts "\tdone."
		puts "inMaintenanceMode? = #{miqHost.inMaintenanceMode?}"
	end

rescue => err
	puts err.class.to_s
    puts err.to_s
    puts err.backtrace.join("\n")
ensure
	miqCluster.release if miqCluster
	hvim.disconnect unless hvim.nil?
    vim.disconnect
end
