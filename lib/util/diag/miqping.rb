#!/usr/bin/env ruby script/runner

require 'soap/rpc/driver'
require 'ostruct'
require 'optparse'

module Manageiq
	class MiqWsPing
		def self.defaults
			{
			:host => "localhost",
			:port => 3000,
			:total => 5,
			:bytes => 64,
			:debug => 1,
			:mode => "server",
			}
		end
		
		def self.ping(cfg)
			cfg.data = ""
			cfg.bytes.times {cfg.data += "*"} 
			
			cfg.mode = "agent" if cfg.port == 1139
			if cfg.mode == "agent"
				ws = "miqPing"
			else
				ws = "MiqPing"
			end
			
			puts "Pinging [#{cfg.host}:#{cfg.port}] with [#{cfg.bytes}] bytes of data:"
			
			driver = SOAP::RPC::Driver.new("http://#{cfg.host}:#{cfg.port}/miqservices/api", 'urn:Miqws')
			# driver.add_method(ws, 'param0')
			driver.add_method_with_soapaction_as(ws, ws, "/miqservices/api/MiqPing", 'data')
			
			if cfg.debug == 1
				dfile = "miq_ping_wire_dump.out"
				File.delete(dfile) if File.exist?(dfile)
				wdFile = File.new("miq_ping_wire_dump.out", "w")
				driver.wiredump_dev = wdFile
			end

			cfg.total.times {|pass|
				begin
					t1 = Time.now
					result = driver.send(ws, cfg.data)
				rescue TimeoutError
					puts "ERROR: TimeoutError after [#{Time.now - t1}] seconds"
				rescue => err
					puts "ERROR: #{err}"
				end
				puts "#{cfg.data.length} bytes from #{cfg.host}: time=#{Time.now - t1}s"
			}
		end
	end
end

# Only run if we are calling this script directly
if __FILE__ == $0 then

	cfg = OpenStruct.new(Manageiq::MiqWsPing.defaults)

	opts = OptionParser.new
	opts.on('--host=<host>', 'remote host name or ip address', String) {|val| cfg.host = val}
	opts.on('--port=<port>', 'remote listening port number', Integer) {|val| cfg.port = val}
	opts.on('--total=<number>', 'numner of ping transactions to execute', Integer) {|val| cfg.total = val}
	opts.on('--bytes=<number>', 'number of bytes to send to remote node', Integer) {|val| cfg.bytes = val}
	opts.on('--debug=[0|1]', 'enable/disable wire trace', Integer) {|val| cfg.debug = val}
	opts.on('--mode=[agent|server]', 'ping agent or server', String) {|val| cfg.mode = val}
	opts.parse(*ARGV) unless ARGV.empty?
	
	Manageiq::MiqWsPing.ping(cfg)
end
