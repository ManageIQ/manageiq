module XmlBlackBox
	def getBaseBlackBoxName
		dir, dfBase, ext = File.splitpath(@config_name)
		ext = ".vhd"
		
		# Add the disk file and an optional descriptor file
		File.normalize(File.join(dir, dfBase + Manageiq::BlackBox::BLACKBOX_NAME + ext))
	end
	
	def getExtractFiles
		["MiqBB.vhd"]
	end
	
	def updateCfgFile
		return true
	end	
	
	def deleteFromCfgFile
	end
end