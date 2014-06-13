module VmxBlackBox    
	#TODO Un-hardcode this with code to determine the next available device
	CONTROLLER = "scsi3"
	DEVICENUM = "15"
  
	def getBaseBlackBoxName
		dir, dfBase, ext = File.splitpath(@config_name)
		ext = ".vmdk"
		
		# Add the disk file and an optional descriptor file
		return File.normalize(File.join(dir, dfBase + Manageiq::BlackBox::BLACKBOX_NAME + ext))
	end

	def getExtractFiles
		["MiqBB.vmdk", "MiqBB#{Manageiq::BlackBox::FLAT_EXT}.vmdk"]
	end

	def postDiskCopy()
		path = getActiveBlackBoxName()
		extractFiles = getExtractFiles
		disks = []
		extractFiles.each {|f| disks << get_destination_path(path, f)}
		
		updateDescriptorFile(disks[1], nil, disks[0])
  end
	
	def getVmUuid
		return @vmCfg.getHash['uuid.bios']
	end

	def updateCfgFile
		begin
			bbBaseName = File.basename(@bbName)
			currText = File.read(@config_name)
			unless self.configured?
				newLines = []
				
				# If the controller is not defined add it.
				unless currText.include?(CONTROLLER)
					newLines << ["#{CONTROLLER}.present = \"true\"",
						"#{CONTROLLER}.virtualDev = \"lsilogic\""]
				end
				
				# Now add our device
				newLines << ["",
					"#{CONTROLLER}:#{DEVICENUM}.deviceType = \"scsi-hardDisk\"",
					"#{CONTROLLER}:#{DEVICENUM}.fileName = \"#{bbBaseName}\"",
					"#{CONTROLLER}:#{DEVICENUM}.mode = \"independent-nonpersistent\"",
					"#{CONTROLLER}:#{DEVICENUM}.present = \"true\"",
					"#{CONTROLLER}:#{DEVICENUM}.redo = \"\""]
				
				newLines = newLines.join("\n")
				
				currText += newLines
				File.open(@config_name, "w") {|f| f.write(currText); f.close}
			end
		rescue
			return false
		end
		return true
	end	

    def updateDescriptorFile(newDisk, oldDisk, descriptor)
        # Do not process anything if the descriptor is nil
        return if descriptor.nil?
                
        newDisk = File.basename(newDisk)
        oldDisk = File.basename(oldDisk) if oldDisk
        oldDisk = "\"" + oldDisk.to_s + "\""
        text = File.read(@bbName)
        if text.include?(oldDisk)
            text.sub!(oldDisk, "\"#{newDisk}\"")

            # The base descriptor file is configured for vmfs.  Convert if needed.
            if @vmCfg.getVmType() == "Server"
                text.sub!("vmfs", "monolithicFlat")
                text.sub!("VMFS","FLAT")
            end
            
            # Update the SCSI bus type if needed
            text.sub!("lsilogic", @vmCfg.getScsiType()) if @vmCfg.getScsiType() != "lsilogic"
            
            File.open(@bbName, "w") {|f| f.write(text)}
        end
    end
    
	def deleteFromCfgFile
		begin
			currText = File.read(@config_name)
			if self.configured?
				currText.gsub!(/^#{CONTROLLER}.+\n?/, '')

				File.open(@config_name, "w") {|f| f.write(currText); f.close}
			end
		rescue
			return false
		end
		return true
	end	
  
  def getBlackboxNameArray()
    names = getActiveBlackBoxName.to_a
    dir, dfBase, ext = File.splitpath(names[0])
    names << File.normalize(File.join(dir, dfBase + Manageiq::BlackBox::FLAT_EXT + ext))

    # Reverse the return array so we always work on the main disk first.
    # Since the descriptor file is rarely locked we should fail earlier if we process
    # the main disk first.
    return names.reverse!
  end
end