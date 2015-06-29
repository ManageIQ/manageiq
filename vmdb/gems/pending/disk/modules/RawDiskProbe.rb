module RawDiskProbe
	def RawDiskProbe.probe(ostruct)
	    return nil if !ostruct.fileName
		return("RawDisk") if ostruct.rawDisk || File.extname(ostruct.fileName).downcase == ".img"
		return(nil)
	end
end
