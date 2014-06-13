module VixDiskProbe
	def VixDiskProbe.probe(ostruct)
		return("VixDiskMod") if ostruct.vixDiskInfo
		return(nil)
	end
end
