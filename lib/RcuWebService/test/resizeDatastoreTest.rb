$:.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
require 'RcuClientBase'

VC				= raise "please define"
VC_USER			= raise "please define"
VC_PASSWORD		= raise "please define"

FILER			= raise "please define"
FILER_USER		= raise "please define"
FILER_PASSWORD	= raise "please define"

TARGET_HOST		= raise "please define"
DS_NAME			= raise "please define"

begin
	
	rcu = RcuClientBase.new(VC, VC_USER, VC_PASSWORD)
	
	controller = RcuHash.new("ControllerSpec") do |cs|
		cs.ipAddress	= FILER
		cs.password		= FILER_PASSWORD
		cs.ssl			= false
		cs.username		= FILER_USER
	end
	
	dsMor = rcu.getMoref(DS_NAME, "Datastore")
	puts "Datastore MOR: #{dsMor}"
			
	datastoreSpec = RcuHash.new("DatastoreSpec") do |ds|
		ds.controller	= controller
		ds.sizeInMB		= 1024 * 6
		ds.mor			= dsMor
	end
		
	puts
	puts "Calling resizeDatastore..."
	rv = rcu.resizeDatastore(datastoreSpec)
	
	puts
	puts "*** RV: #{rv} (#{rv.class.to_s})"

rescue Handsoap::Fault => hserr
	$stderr.puts hserr.to_s
	$stderr.puts hserr.backtrace.join("\n")
rescue => err
	$stderr.puts err.to_s
	$stderr.puts err.backtrace.join("\n")
end
