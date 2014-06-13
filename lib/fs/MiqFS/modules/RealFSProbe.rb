module RealFSProbe
	def RealFSProbe.probe(dobj)
		return(true) if dobj.to_s == "test_disk"
		return(false)
	end
end
