module SharedOps
	def SyncMetadata(ost)
		return if !checkArg(ost)
		begin
      raise "No synchronize category specified" if ost.category.nil?
      categories = ost.category.split(",")
      ost.scanTime = Time.now.utc
      ost.compress = true				# Request that data returned from the blackbox is compressed
      ost.xml_class = REXML::Document

      vmName, bb, vmId = nil
  		driver = get_ws_driver(ost)
    	xml_summary = ost.xml_class.createDoc("<summary/>")
      xmlNode = xml_summary.root.add_element("syncmetadata")
      xml_summary.root.add_attributes({"scan_time"=>ost.scanTime, "taskid"=>ost.taskid})
      ost.skipConfig = true
      vmName = getVmFile(ost)
      bb = Manageiq::BlackBox.new(vmName, ost)

			UpdateAgentState(ost, "Synchronize", "Synchronization in progress")
			categories.each do |c|
				c.gsub!("\"","")
				c.strip!

				# Grab data out of the bb.  (results may be limited by parms in ost like "from_time")
				ret = bb.loadXmlData(c, ost)

				#File.open("d:/temp/#{Time.now.iso8601.gsub(":", "")} #{c}.xml", "w") {|f| ret.xml.write(f, 0)}
				# This logic will convert either libxml or Rexml to a Rexml Element
				xmlNode << ost.xml_class.load(ret.xml.root.shallow_copy.to_xml.to_s).root

        items_total, items_selected = ret.xml.root.attributes["items_total"].to_i, ret.xml.root.attributes["items_selected"].to_i

				data = ret.xml.miqEncode
#        ret.xml = nil
#        GC.start

        # Verify that we have data to send
        unless items_selected.zero?
          $log.info "Starting:  Sending vm data for [#{c}] to server.  Size:[#{data.length}]  TaskId:[#{ost.taskid}]  VM:[#{vmName}]"
          #File.open("d:/temp/#{Time.now.iso8601.gsub(":", "")} #{c}.xml", "w") {|f| ret.xml.write(f, 0)}
          driver.SaveVmmetadata(bb.vmId, data, "b64,zlib,xml", ost.taskid)
          $log.info "Completed: Sending vm data for [#{c}] to server.  Size:[#{data.length}]  TaskId:[#{ost.taskid}]  VM:[#{vmName}]"
        else
          # Do not send empty XMLs.  Warn if there is not data at all, or just not items selected.
          if items_total.zero?
            $log.warn "Synchronize: No data found for [#{c}].  Items:Total[#{items_total}] Selected[#{items_selected}]  TaskId:[#{ost.taskid}]  VM:[#{vmName}]"
          else
            $log.warn "Synchronize: No data selected for [#{c}].  Items:Total[#{items_total}] Selected[#{items_selected}]  TaskId:[#{ost.taskid}]  VM:[#{vmName}]"
          end
        end
			end
    rescue => syncErr
		ensure
      if bb
  			bb.postSync()
      	bb.close
      end
      
      #File.open("d:/temp/#{Time.now.iso8601.gsub(":", "")} sync summary.xml", "w") {|f| xml_summary.write(f, 0)}
      $log.info "Starting:  Sending vm summary to server.  TaskId:[#{ost.taskid}]  VM:[#{vmName}]"
      driver.SaveVmmetadata(vmId, xml_summary.miqEncode, "b64,zlib,xml", ost.taskid)
      $log.info "Completed: Sending vm summary to server.  TaskId:[#{ost.taskid}]  VM:[#{vmName}]"
      
#      xml_summary = nil
#      GC.start
			
			UpdateAgentState(ost, "Synchronize", "Synchronization complete")

      raise syncErr if syncErr
		end
		ost.value = "OK\n"

    #$seek_file.close unless $seek_file.nil?
    #$seek_file = nil
	end
	
	def ScanMetadata(ost)
    return if !checkArg(ost)

    begin
      # Get the YAML from args
      if ost.args[1]
        dataHash = ost.args[1]
        dataHash = dataHash[1..-2] if dataHash[0,1] == '"' and dataHash[-1,1] == '"'
        dataHash = YAML.load(dataHash)

        #$log.info "Scan hash:\n#{YAML.dump(dataHash)}"
        ost.scanData = dataHash.is_a?(Hash) ? dataHash : {}
      end

      # Initialize stat collection variables
      ost.scanTime = Time.now.utc unless ost.scanTime
      status = "OK"; statusCode = 0; scanMessage = "OK"
      categoriesProcessed = 0
      ost.xml_class = XmlHash::Document

      UpdateAgentState(ost, "Scanning", "Initializing scan")
      vmName, bb, vmId, lastErr, vmCfg = nil
  		xml_summary = ost.xml_class.createDoc(:summary)
      xmlNode = xmlNodeScan = xml_summary.root.add_element("scanmetadata")
    	xmlNodeScan.add_attributes("start_time"=>ost.scanTime.iso8601)
  		xml_summary.root.add_attributes("taskid"=>ost.taskid)

      vmName = getVmFile(ost)
			vmCfg = MIQExtract.new(vmName, ost)
      ost.miqVm = vmCfg
    	bb = Manageiq::BlackBox.new(vmName, ost)
        
      vmId = bb.vmId

			# Check if we have a valid filesystem handle to work with.  Otherwise, throw an error.
			raise vmCfg.systemFsMsg unless vmCfg.systemFs
            
			# Collect data for each of the specified categories
      categories = vmCfg.categories
      categoryCount = categories.length
			categories.each do |c|				
				# Update job state
				UpdateAgentState(ost, "Scanning", "Scanning #{c}")
				$log.info "Scanning [#{c}] information.  TaskId:[#{ost.taskid}]  VM:[#{vmName}]"
				
				# Get the proper xml file
				st = Time.now
				begin
					xml = vmCfg.extract(c) {|scan_data| UpdateAgentState(ost, "Scanning", scan_data[:msg])}
					categoriesProcessed += 1
				rescue NoMethodError => lastErr
					ost.error = "#{lastErr} for VM:[#{vmName}]"
					$log.error "Scanmetadata extract error - [#{lastErr}]"
					$log.error "Scanmetadata extract error - [#{lastErr.backtrace.join("\n")}]"
				rescue => lastErr
					ost.error = "#{lastErr} for VM:[#{vmName}]"
					#$log.error "Scanmetadata extract error - [#{lastErr}]"
					#$log.error "Scanmetadata extract error - [#{lastErr.backtrace.join("\n")}]"
				end
				$log.info "Scanning [#{c}] information ran for [#{Time.now-st}] seconds.  TaskId:[#{ost.taskid}]  VM:[#{vmName}]"
				if xml
					xml.root.add_attributes({"created_on" => ost.scanTime.to_i, "display_time" => ost.scanTime.iso8601})
					$log.debug "Writing scanned data to XML for [#{c}] to blackbox."
					bb.saveXmlData(xml, c)
					$log.debug "writing xml complete."
					# This logic will convert either libxml or Rexml to a Rexml Element
					categoryNode = xml_summary.class.load(xml.root.shallow_copy.to_xml.to_s).root
					categoryNode.add_attributes("start_time"=>st.utc.iso8601, "end_time"=>Time.now.utc.iso8601)
					xmlNode << categoryNode
#          categoryNode = nil
#          xml = nil
#          GC.start
				else
					# Handle categories that we do not expect to return data.
					# Otherwise, log an error if we do not get data back.
					unless c == "vmevents"
						$log.error "Error: No XML returned for category [#{c}]  TaskId:[#{ost.taskid}]  VM:[#{vmName}]"
					end
				end
			end
		rescue NoMethodError => scanErr
			lastErr = scanErr
			$log.error "Scanmetadata Error - [#{scanErr}]"
			$log.error "Scanmetadata Error - [#{scanErr.backtrace.join("\n")}]"
		rescue Timeout::Error, StandardError => scanErr
			lastErr = scanErr
			#$log.error "Scanmetadata Error - [#{scanErr}]"
			#$log.error "Scanmetadata Error - [#{scanErr.backtrace.join("\n")}]"
		ensure
			vmCfg.close unless vmCfg.nil?
      bb.close if bb

			UpdateAgentState(ost, "Scanning", "Scanning completed.")

			# If we are sent a TaskId transfer a end of job summary xml.
			$log.info "Starting:  Sending scan summary to server.  TaskId:[#{ost.taskid}]  VM:[#{vmName}]"
			if lastErr
				status = "Error"
				statusCode = 8
				statusCode = 16 if categoriesProcessed.zero?
				scanMessage = lastErr.to_s
        $log.error "ScanMetadata error status:[#{statusCode}]:  message:[#{lastErr}]"
        lastErr.backtrace.each {|m| $log.debug m} if $log.debug?
			end
			xmlNodeScan.add_attributes("end_time"=>Time.now.utc.iso8601, "status"=>status, "status_code"=>statusCode.to_s, "message"=>scanMessage)
			#File.open("d:/temp/#{Time.now.iso8601.gsub(":", "")} scan summary.xml", "w") {|f| xml_summary.write(f, 0)}
			driver = get_ws_driver(ost)
			driver.SaveVmmetadata(vmId, xml_summary.to_xml.miqEncode, "b64,zlib,xml", ost.taskid)
			$log.info "Completed: Sending scan summary to server.  TaskId:[#{ost.taskid}]  VM:[#{vmName}]"
      
#      xml_summary = nil
#      GC.start
        ost.error = "#{lastErr} for VM:[#{vmName}]" if lastErr

        #$seek_file.close unless $seek_file.nil?
        #$seek_file = nil
      end
		ost.value = "OK\n"
	end
	
	def UpdateAgentState(ost, state, message)
		ost.agent_state = state
		ost.agent_message = message
		AgentJobState(ost)
	end
	
	def AgentJobState(ost)
    begin
      driver = get_ws_driver(ost)
      driver.AgentJobState(ost.taskid, ost.agent_state, ost.agent_message) if ost.taskid && ost.taskid.empty? == false
    rescue
    end
	end

  def TaskUpdate(ost)
    begin
      task_id, state, status, message = ost.args[0], ost.args[1], ost.args[2], ost.args[3]
      driver = get_ws_driver(ost)
      driver.TaskUpdate(task_id, state, status, message)
    rescue
      $log.error $!
      $log.debug $!.backtrace.join("\n")
    end
  end

	def GetVMConfig(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)
		driver = get_ws_driver(ost)
		
		vmId = Manageiq::BlackBox.vmId(vmName)
		cfg = VmConfig.new(vmName)
		cfg.dump_config_to_log(:debug)
		xml = cfg.toXML(false)
		driver.SaveVmmetadata(vmId, xml.miqEncode, "b64,zlib,xml", nil)
		ost.value = "OK\n"
	end
	
	def RegisterId(ost)
		return if !checkArg(ost)
		if (!ost.vmId)
			ost.error = "ID value not supplied\n"
			ost.show_help = true
			return
		end
		vmName = getVmFile(ost)
		bb = Manageiq::BlackBox.new(vmName)
		bb.vmId = ost.vmId
		bb.close
		ost.value = "OK\n"
	end
	
	def RegisterVM(ost)
		vmName = getVmFile(ost)
		
		cfg = VmConfig.new(vmName).getHash
		driver = get_ws_driver(ost)
		ost.value = driver.RegisterVm(cfg["displayname"], vmName, "vmware")
		
		idFile = getVmMdFile(vmName, "miq.id")
		f = File.new(idFile, "w+")
		f.print(ost.value)
		f.close
	end
	
	def SaveVmMetadata(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)
		
		driver = get_ws_driver(ost)
		ost.value = driver.SaveVmMetadata(1, "uri:" + vmName)
	end
	
	def SaveHostMetadata(ost)
		hostId = ost.args[0]
    data = ost.args[1]
    data_type = ost.args[2]

    driver = get_ws_driver(ost)
    if data_type == 'yaml'
      driver.SaveHostmetadata(hostId, YAML.dump(data), 'yaml')
    elsif data_type == 'b64,zlib,yaml'
      driver.SaveHostmetadata(hostId, data, data_type)
    else
      driver.SaveHostmetadata(hostId, data.miqEncode, "b64,zlib,xml")
    end
		ost.value = "OK\n"
	end
	
	def HostHeartbeat(ost)
		hostId = ost.args[0]
		xmlDoc = ost.args[1]
		driver = get_ws_driver(ost)
		ost.value = driver.HostHeartbeat(hostId, xmlDoc.miqEncode, "b64,zlib,xml")
	end
	
	def SendVMState(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)
		vmState = ost.args[1]
		vmId = ost.args[2]
    
		driver = get_ws_driver(ost)
		
		vmId = Manageiq::BlackBox.vmId(vmName) if vmId.nil?
		return ost.value = "Unregistered VM [#{vmName}]" if vmId.nil?
		
		# Encode the local XML config files and send them to the Rails ws.
		driver.VmStatusUpdate(vmId, vmState)
		
		ost.value = "OK\n"
	end
	
	def checkArg(ost)
		if (!ost.args || (ost.args.length == 0))
			ost.error = "Command requires an argument\n"
			ost.show_help = true
			return(false)
		end
		return(true)
	end
	
	def getVmMdFile(vmName, sfx)
		ext = File.extname(vmName)
		fbn = File.basename(vmName, ext)
		dir = File.dirname(vmName)
		
		File.join(dir, fbn + "_" + sfx)
	end
	
	def get_ws_driver(ost)
    @vmdbDriver ||= MiqservicesClient.get_driver(ost.config)
	end
		
	def renameDisks (diskFile, diskFileSave, bbFileSave)
		
		return	#NOP
		
		attempt = 0
		begin
			#
			# Now that the VM has started, let's reset...
			# 
			# Save the VM's disk file.
			# 
			File.rename(diskFile, diskFileSave) if File.exist?(diskFile)
			#
			# Restore the black box.
			# 
			File.rename(bbFileSave, diskFile) if File.exist?(bbFileSave)
		rescue => err #Errno::EACCES
			sleep(0.1)
			attempt+=1
			retry unless attempt > 20
		end
	end
	
	def isSmart?(vmName)
		# Set Internal blackbox smart flag to true, if not already
		bb = Manageiq::BlackBox.new(vmName)
		vmSmart = bb.smart
		bb.close
		return vmSmart
	end
	
	def formatVmHash(vm, add_hash={})
		vm.strip!
		config = VmConfig.new(vm)
		vmId = Manageiq::BlackBox.vmId(vm)
		add_hash.merge({:name => config.getHash["displayname"], :vendor => config.vendor, :location => vm, :guid=>vmId})
	end
	
	def formatVmList(ra, ost)
		if !ost.fmt
			ost.value = ""
			ra.each { |h| ost.value += "#{h[:name]}\t#{h[:vendor]}\t#{h[:location]}\n" }
			puts ost.value
		else
			ost.value = ra.inspect
		end
	end
end
