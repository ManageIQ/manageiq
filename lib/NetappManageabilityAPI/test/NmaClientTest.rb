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
	
	puts
	puts "*** No options - list info for all volumes:"
	rv = nma.volume_list_info
	dump.dumpObj(rv)
	
	#
	# Different ways of mking the same call.
	#
	puts
	puts "*** List info for a specific volume V1:"
	rv = nma.volume_list_info(:volume => "vol1")
	dump.dumpObj(rv)
	
	puts
	puts "*** List info for a specific volume V2:"
	rv = nma.volume_list_info(:volume, "vol1")
	dump.dumpObj(rv)
	
	puts
	puts "*** List info for a specific volume V3:"
	rv = nma.volume_list_info {
		volume "vol1"
	}
	dump.dumpObj(rv)
	
	puts
	puts "*** List info for a specific volume V4:"
	rv = nma.volume_list_info { |vla|
		vla.volume = "vol1"
	}
	dump.dumpObj(rv)
	
rescue => err
	puts err.to_s
	puts err.backtrace.join("\n")
end
