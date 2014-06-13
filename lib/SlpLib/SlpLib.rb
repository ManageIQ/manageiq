require_relative 'SlpLib_raw'

class SlpLib
	
	attr_reader :slpHandle
	
	def initialize(lang=nil, isasync=false)
		@slpHandle = SlpLib_raw.open(lang, isasync)
	end
	
	def close
		SlpLib_raw.close(@slpHandle)
	end
	
	def findSrvs(srvtype, scopelist=nil, filter=nil)
		SlpLib_raw.findSrvs(@slpHandle, srvtype, scopelist, filter)
	end
	
	def findAttrs(srvurl, scopelist=nil, attrids=nil)
		attrs = SlpLib_raw.findAttrs(@slpHandle, srvurl, scopelist, attrids)
		attrHash = {}
		aa = attrs[1...-1].split("),(")
		aa.each { |a| attrHash.store(*a.split("=")) }
		
		if (rps = attrHash['RegisteredProfilesSupported'])
			attrHash['RegisteredProfilesSupported'] = rps.split(',')
		end
		
		return attrHash
	end
	
	def parseSrvURL(srvurl)
		SlpLib_raw.parseSrvURL(srvurl)
	end
	
end # class SlpLib

if __FILE__ == $0
	begin
		
		slp = SlpLib.new
		
		slp.findSrvs("service:wbem").each do |surl|
			puts "*** #{surl}"
			slp.parseSrvURL(surl).each { |k,v| puts "\t\t#{k}	=> #{v}" }
			puts
			attrs = slp.findAttrs(surl)
			attrs.each do |ak, av|
				next if ak == 'RegisteredProfilesSupported'
				puts "\t#{ak}	=> #{av}"
			end
			if (rps = attrs['RegisteredProfilesSupported'])
				puts "\t*** RegisteredProfilesSupported:"
				rps.each { |p| puts "\t\t#{p}" }
			end
		end
		slp.close
		
	rescue => err
		$stderr.puts err
		$stderr.puts err.backtrace.join("\n")
	end
end
