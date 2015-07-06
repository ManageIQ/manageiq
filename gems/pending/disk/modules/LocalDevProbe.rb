module LocalDevProbe
	def LocalDevProbe.probe(ostruct)
		return("LocalDevMod") if ostruct.localDev || File.blockdev?(ostruct.fileName)
		return(nil)
	end
end
