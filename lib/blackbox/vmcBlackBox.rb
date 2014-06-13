module VmcBlackBox
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
		xml = MiqXml.loadFile(File.open(@config_name))
		
		absolute_path = nil
		location = nil
		idx = nil
		1.downto(0) do |c|
			# See if the controller exists.  Skip it.
			controller = xml.find_first("//preferences/hardware/pci_bus/ide_adapter/ide_controller[@id=\"#{c}\"]")
			if controller
				1.downto(0) do |l|
					if location.nil?
						element = xml.find_first("//preferences/hardware/pci_bus/ide_adapter/ide_controller[@id=\"#{c}\"]/location[@id=\"#{l}\"]")
						if element.nil?
							# Save the location where we want the new element added
							location = controller
							# Save the free index number within the controller to use
							idx = l
						end
					end
					
					# Find an absolute path to use
					if absolute_path.nil?
						element = xml.find_first("//preferences/hardware/pci_bus/ide_adapter/ide_controller[@id=\"#{c}\"]/location[@id=\"#{l}\"]/pathname/absolute")
						if element
							absolute_path = File.dirname(element.text) if element.text && element.text.empty? == false
							
						end
					end
				end
			end
			break if location && absolute_path
		end
		
		if location
			relative = ".\\#{File.basename(@bbName)}"
			absolute = File.join(absolute_path, File.basename(@bbName)).gsub("/", "\\")
			xml_seg = MiqXml.load("<location id=\"#{idx}\"><drive_type type=\"integer\">1</drive_type><pathname><absolute type=\"string\">#{absolute}</absolute><relative type=\"string\">#{relative}</relative></pathname><undo_pathname><absolute type=\"string\" /><relative type=\"string\" /></undo_pathname></location>")
			location << xml_seg.root
			File.open(@config_name,"w") {|f| xml.write(f,0)}
		end
		
		return true
	end	
	
	def deleteFromCfgFile
		xml = MiqXml.loadFile(File.open(@config_name))
		relative = ".\\#{File.basename(@bbName)}"
		
		#find the element for this black box
		element = xml.find_first("//preferences/hardware/pci_bus/ide_adapter/ide_controller/location/pathname/relative/[#{relative}]")
		if element
			location = element.parent.parent.parent
			controller = location.parent
			controller.delete_element(location)
			File.open(@config_name,"w") {|f| xml.write(f,0)}
		end
	end
end	