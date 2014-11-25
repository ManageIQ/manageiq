$:.push("#{File.dirname(__FILE__)}/..")

require "NmaCore"
require "../util/MiqDumpObj"

class Dump
	include MiqDumpObj
end

begin
	dump = Dump.new
	
	svr = NmaCore_raw.server_open(SERVER, 1, 1)
	NmaCore_raw.server_style(svr, NmaCore_raw::NA_STYLE_LOGIN_PASSWORD)
	NmaCore_raw.server_adminuser(svr, USERNAME, PASSWORD)
	rv = NmaCore_raw.server_invoke(svr, "volume-list-info", :volume => "vol1")
	
	puts "RV: #{rv.class}"
	dump.dumpObj(rv)
	
rescue => err
	puts err.to_s
	puts err.backtrace.join("\n")
end
