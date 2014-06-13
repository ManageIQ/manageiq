$:.push("#{File.dirname(__FILE__)}/..")

require 'rubygems'
require 'log4r'
require "NmaClient"
require "../util/MiqDumpObj"

class ConsoleFormatter < Log4r::Formatter
	def format(event)
		"**** " + (event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end
$vim_log = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::DEBUG, :formatter=>ConsoleFormatter)
$vim_log.add 'err_console'

SERVER			= raise "please define server"
USERNAME		= ""
PASSWORD		= ""

GB				= 1024 * 1024 *1024
CONTAINING_AGGR	= "aggr1"
NEW_VOLUME		= "api_test_vol1"
VOL_SIZE_GB		= 10
NFS_PATH		= "/vol/#{NEW_VOLUME}"
ROOT_HOSTS		= [ HOST1, HOST2 ]

class Dump
	include MiqDumpObj
end

begin
	
	dump = Dump.new
	
	NmaClient.logger	= $vim_log
	NmaClient.wire_dump	= false
	
	nma = NmaClient.new {
		server		SERVER
		auth_style	NmaClient::NA_STYLE_LOGIN_PASSWORD
		username	USERNAME
		password	PASSWORD
	}
	
	#
	# Ensure the volume doesn't already exist.
	#
	err = false
	begin
		nma.volume_list_info(:volume, NEW_VOLUME)
		err = true
	rescue
		# Ignore expected failure
	end
	raise "Volume #{NEW_VOLUME} already exists" if err
	
	#
	# Make sure there's enough free space in the aggregate for the new volume.
	#
	rv = nma.aggr_list_info(:aggregate, CONTAINING_AGGR)
	aggr_free_space = rv.aggregates.aggr_info.size_available.to_i
	raise "Insufficient free space in #{CONTAINING_AGGR}: #{aggr_free_space}" if aggr_free_space < VOL_SIZE_GB * GB
	
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
		rv = nma.options_set {
			name	'wafl.default_security_style'
			value	'mixed'
		}
	end
	
	#
	# Create the volume within the given aggregate.
	#
	rv = nma.volume_create {
		containing_aggr_name	CONTAINING_AGGR
		volume					NEW_VOLUME
		space_reserve			"none"
		size					"#{VOL_SIZE_GB}g"
	}
	
	#
	# Get the export rules for the new volume's NFS share.
	#
	rv = nma.nfs_exportfs_list_rules(:pathname, NFS_PATH)
	# dump.dumpObj(rv)
	
	#
	# Add a list of root access hosts to the rules.
	# These are the ESX hosts that will be able to access the datastore.
	#
	rules = rv.rules
	rules.exports_rule_info.root = NmaHash.new {
		exports_hostname_info NmaArray.new {
			ROOT_HOSTS.each do |rh|
				push NmaHash.new { name rh }
			end
		}
	}
	# dump.dumpObj(eri)
	
	#
	# Update the export rules with the root access host list.
	#
	rv = nma.nfs_exportfs_modify_rule {
		persistent	true
		rule		rules
	}
	
rescue => err
	puts err.to_s
	puts err.backtrace.join("\n")
end
