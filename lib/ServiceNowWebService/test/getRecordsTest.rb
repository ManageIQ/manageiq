# $:.push("#{File.dirname(__FILE__)}/../..") # miq/lib
$:.push("/var/www/miq/lib")

require_relative '../../bundler_setup'
require 'ServiceNowWebService/SnSctaskClientBase'

server = "manageiqdev.service-now.com"

params = {
	"state"				=> 1,
	"request_item"		=> "RITM0010631",
	"short_description"	=> "Provide Network Configuration to EVM"
}

begin
	
	sn = SnSctaskClientBase.new(server, "itil", "itil")
	rva = sn.getRecords(params)
	
	puts
	puts "*** RV:"
	# sn.dumpObj(rva)
	rva.each do |rv|
		#
		# Variables can also be accessed via hash notation: rv['short_description']
		#
		puts "\t#{rv.number}"
		puts "\t\tshort description: #{rv.short_description}"
		puts "\t\tdue date:          #{rv.due_date}"
		puts "\t\tactive:            #{rv.active}"
		puts "\t\tsys_id:            #{rv.sys_id}"
		puts
		
		va = rv.variables.variable
		va = [] if va.nil?
		va = [ va ] unless va.kind_of?(Array)
		va.each do |v|
			puts "\t\t#{v.name}:    #{v.value}"
			
			ca = v.children.variable
			ca = [] if ca.nil?
			ca = [ va ] unless ca.kind_of?(Array)
			
			puts "\t\t\tChildren:"
			ca.each do |c|
				puts "\t\t\t\t#{c.name}:    #{c.value}"
			end
		end
		
		sn.update({ "sys_id" => rv.sys_id, "state" => 1}) # keep state 1 to test - should be 3
	end

rescue Handsoap::Fault => hserr
	$stderr.puts hserr.to_s
	$stderr.puts hserr.backtrace.join("\n")
rescue => err
	$stderr.puts err.to_s
	$stderr.puts err.backtrace.join("\n")
end
