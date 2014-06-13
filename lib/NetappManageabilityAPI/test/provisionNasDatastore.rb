$:.push("#{File.dirname(__FILE__)}/..")

require 'rubygems'
require 'log4r'
require '../VMwareWebService/MiqVim'
require '../VMwareWebService/MiqVimBroker'
require "../util/MiqDumpObj"

require "NmaClient"

class ConsoleFormatter < Log4r::Formatter
	def format(event)
		"**** " + (event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end
$vim_log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::INFO, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

$stdout.sync = true
# $miq_wiredump = true

GB				= 1024 * 1024 * 1024

NAS_SERVER		= raise "please define"
NAS_USERNAME	= ""
NAS_PASSWORD	= ""

CONTAINING_AGGR	= "aggr1"
NEW_VOLUME		= "api_test_vol1"
VOL_SIZE_GB		= 10
NFS_PATH		= "/vol/#{NEW_VOLUME}"

TARGET_HOSTS	= raise "please define array of host names"
LOCAL_PATH		= NEW_VOLUME.tr('_', '-')		# Datastore names cannot contain underscores
ACCESS_MODE		= "readWrite"

begin
	
	broker = MiqVimBroker.new(:client)
	vim = broker.getMiqVim(SERVER, USERNAME, PASSWORD)
	
	puts "vim.class: #{vim.class.to_s}"
    puts "#{vim.server} is #{(vim.isVirtualCenter? ? 'VC' : 'ESX')}"
    puts "API version: #{vim.apiVersion}"
    puts
		
	NmaClient.logger	= $vim_log
	NmaClient.wire_dump	= false
	
	puts "Connecting to NAS server: #{NAS_SERVER}..."
	nma = NmaClient.new {
		server		NAS_SERVER
		auth_style	NmaClient::NA_STYLE_LOGIN_PASSWORD
		username	NAS_USERNAME
		password	NAS_PASSWORD
	}
	puts "done."
	puts
	
	#
	# Ensure the volume doesn't already exist.
	#
	puts "Checking to see if volume #{NEW_VOLUME} already exists..."
	err = false
	begin
		nma.volume_list_info(:volume, NEW_VOLUME)
		err = true
	rescue
		# Ignore expected failure
	end
	raise "Volume #{NEW_VOLUME} already exists" if err
	puts "Volume #{NEW_VOLUME} does not exist"
	puts
	
	#
	# Make sure there's enough free space in the aggregate for the new volume.
	#
	puts "Checking space on containing aggregate: #{CONTAINING_AGGR}"
	rv = nma.aggr_list_info(:aggregate, CONTAINING_AGGR)
	aggr_free_space = rv.aggregates.aggr_info.size_available.to_i
	raise "Insufficient free space in #{CONTAINING_AGGR}: #{aggr_free_space}" if aggr_free_space < VOL_SIZE_GB * GB
	puts "Containing aggregate: #{CONTAINING_AGGR} has sufficient free space"
	puts
	
	#
	# The creation of the volume will result in the creation a qtree entry for its root.
	# If we want to base a VMware datastore on the volume's NFS share, the security style of
	# its corresponding qtree must not be 'ntfs'.
	#
	# Unfortunately, the API doesn't provide a way to specify this value or change it after the fact.
	# The security style is always set to the value of the 'wafl.default_security_style' option.
	# So we must ensure that this value is set to either 'unix' or 'mixed' before the volume is created.
	#
	rv = nma.options_get(:name, 'wafl.default_security_style')
	if rv.value == "ntfs"
		puts "Default security style is ntfs, resetting it to mixed"
		nma.options_set {
			name	'wafl.default_security_style'
			value	'mixed'
		}
	end
	
	#
	# Create the volume within the given aggregate.
	#
	puts "Creating volume: #{NEW_VOLUME} in aggregate: #{CONTAINING_AGGR} on NAS server: #{NAS_SERVER}..."
	rv = nma.volume_create {
		containing_aggr_name	CONTAINING_AGGR
		volume					NEW_VOLUME
		space_reserve			"none"
		size					"#{VOL_SIZE_GB}g"
	}
	puts "done."
	puts
	
	puts "Updating rules for export: #{NEW_VOLUME}..."
	#
	# Get the export rules for the new volume's NFS share.
	#
	rv = nma.nfs_exportfs_list_rules(:pathname, NFS_PATH)
	
	#
	# Ensure the target hosts have root access to the share.
	#
	rules = rv.rules
	rules.exports_rule_info.root = NmaHash.new {
		exports_hostname_info NmaArray.new {
			TARGET_HOSTS.each do |rh|
				push NmaHash.new { name rh }
			end
		}
	}
	
	#
	# Update the export rules with the root access host list.
	#
	rv = nma.nfs_exportfs_modify_rule {
		persistent	true
		rule		rules
	}
	puts "done."
	puts
	
	#
	# Attach the new NFS share as a datastore on each of the desired hosts.
	#
	TARGET_HOSTS.each do |th|
		begin
			miqHost = vim.getVimHost(th)
			puts "Got object for host: #{miqHost.name}"
		rescue => err
			puts "Could not find host: #{th}"
			next
		end
	
		miqDss = miqHost.datastoreSystem
	
		puts
		puts "Creating datastore: #{LOCAL_PATH} on host: #{th}..."
		miqDss.createNasDatastore(NAS_SERVER, NFS_PATH, LOCAL_PATH, ACCESS_MODE)
		miqHost.release
		puts "done."
		puts
	end
	
rescue => err
	puts err.to_s
	puts err.backtrace.join("\n")
end
