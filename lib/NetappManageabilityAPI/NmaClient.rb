require 'rubygems'
require 'platform'

if Platform::IMPL == :linux
	begin
		require File.join(File.dirname(__FILE__), "NmaClient_impl")
	rescue LoadError => lerr
		class NmaClient
			def initialize(opts={}, &block)
				raise "NmaCore could not be loaded on this system: #{@@err_msg}"
			end

			def self.method_missing(sym, *args)
				raise "NmaCore could not be loaded on this system: #{@@err_msg}"
			end
			
			def self.err_msg=(msg)
				@@err_msg = msg
			end
		end
		NmaClient.err_msg = lerr.to_s
	end
else
	class NmaClient
		def initialize(opts={}, &block)
			raise "NmaClient is not available for platform #{Platform::IMPL}"
		end
		
		def self.method_missing(sym, *args)
			raise "NmaClient is not available for platform #{Platform::IMPL}"
		end
	end
end
