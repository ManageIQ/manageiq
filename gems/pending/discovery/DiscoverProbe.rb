module DiscoverProbe
	MODDIR = File.join(File.dirname(__FILE__), "modules")
	
	def self.getProductMod(dobj)
		Dir.foreach(MODDIR) do |pmf|
			next if !File.fnmatch('?*Probe.rb', pmf)
			pmod = pmf.chomp(".rb")
			require_relative "modules/#{pmod}"
			Object.const_get(pmod).probe(dobj)
		end
		return(nil)
	end
end
