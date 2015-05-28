$:.push(Rails.root.join("../lib/util/xml"))

# TODO: Nothing appears to be using xml_utils in this file???
# Perhaps, it's being required here because lower level code requires xml_utils to be loaded
# but wrongly doesn't require it itself.
require 'xml_utils'
require 'blackbox/VmBlackBox'

module VmOrTemplate::Scanning
  extend ActiveSupport::Concern

  module ClassMethods

    def default_scan_categories_no_profile
      self.default_scan_categories - ["profiles"]
    end

    def default_scan_categories
      %w{vmconfig accounts software services system profiles}
    end

    # Processes the scan metadata from miqhost
    def save_metadata(vmId, dataArray)
      xmlFile, data_type = Marshal.load(dataArray)
      vm = self.base_class.find_by_id(vmId)
      xmlFile = MIQEncode.decode(xmlFile) if data_type.include?('b64,zlib')
      begin
        doc = MiqXml.load(xmlFile)
      rescue REXML::ParseException => err
        n = MiqXml.load(xmlFile, :nokogiri)
        xmlFile = n.to_s
        doc = MiqXml.load(xmlFile)
      end


      taskid = doc.root.attributes["taskid"]
      $log.info("MIQ(Vm-save_metadata) TaskId = [#{taskid}]")
      unless taskid.blank?
        name = (File.basename(doc.root.elements[1].elements[1].attributes["original_filename"], ".*") rescue "vmscan")
        # Write vm xml to the vmdb directory for debugging
        #File.open("./xfer_#{name}.xml", "w") {|f| doc.write(f,0); f.close} rescue nil
        job = Job.find_by_guid(taskid)
        raise "Unable to process data for job with id <#{taskid}>.  Job not found." if job.nil?
        begin
          job.signal(:data, xmlFile)
        rescue => err
          $log.error("MIQ(Vm-save_metadata) Processing xml for [#{name}] [#{err}]")
          $log.error("MIQ(Vm-save_metadata) Processing xml for [#{name}] #{err.backtrace.join("\n")}")
        end
      end

      case(doc.root.name.downcase)
      when "summary"
        $log.info("MIQ(Vm-save_metadata) Summary XML received. [#{doc.root.to_s[0..100]}]")
      when "vmmetadata"
        # doc being sent up has a some extra header elements we need to remove (<vmmetadata>, and <item>)
        begin
          # Reset the root of the xml document to match the expected starting point
          doc.root = doc.root.elements[1].elements[1]
        rescue => err
          $log.error "MIQ(Vm-save_metadata) Invalid xml error [#{err}] for xml:[#{doc}]"
        end
        vm.add_elements(doc)
        vm.save!
      when "vmevents"
        vm.add_elements(doc)
        vm.save!
      else
        vm.add_elements(doc)
        vm.save!
      end
    end

  end

  # Process XML documents from VM scans
  def add_elements(xmlNode)
    return if xmlNode.nil?
    $log.info("Adding XML elements for [#{self.id}] from [#{xmlNode.root.name}]")
    updated = false

    # Find out what XML file document we are being passed.
    case xmlNode.root.name
    when "miq"
      for element_class in [OperatingSystem, Account, SystemService, GuestApplication, Patch, Network]
        begin
          element_class.add_elements(self, xmlNode)
          updated = true
        rescue Exception => err
          $log.log_backtrace(err)
        end
      end
    when "scan_profiles"
      ScanItem.add_elements(self, xmlNode)
      updated = true
    when "vm_configuration"
      Hardware.add_elements(self, xmlNode)
      updated = true
    when "vmevents"
      # Record vm operational and configuration events
      MiqEvent.add_elements(self, xmlNode)
    end
    # Update the last sync time if we did something
    # self.last_sync_on = Time.new.utc  if updated == true
    self.last_sync_on = Time.at(xmlNode.root.attributes["created_on"].to_i).utc if updated == true && xmlNode.root.attributes["created_on"]
    self.save
    self.hardware.save unless self.hardware.nil?
  end

  def scan_queue(userid = "system", options={})
    MiqQueue.put(
      :class_name  => self.class.base_class.name,
      :instance_id => self.id,
      :method_name => "scan",
      :args        => [userid, options]
    )
  end

  # Call the VmScan Job and raise a "request" event
  def scan(userid = "system", options={})
    # Check if there are any current scan jobs already waiting to run
    j = VmScan.where(:state => 'waiting_to_start')
          .where(:sync_key => guid)
          .pluck(:id)
    unless j.blank?
      $log.info "(Vm-scan) VM scan job will not be added due to existing scan job waiting to be processed.  VM ID:[#{self.id}] Name:[#{self.name}] Guid:[#{self.guid}]  Existing Job IDs [#{j.join(", ")}]"
      return nil
    end

    options = {
      :target_id => self.id,
      :target_class => self.class.base_class.name,
      :name => "Scan from Vm #{self.name}",
      :userid => userid,
      :sync_key => self.guid
    }.merge(options)
    options[:zone] = self.ext_management_system.my_zone unless self.ext_management_system.nil?
    # options = {:agent_id => myhost.id, :agent_class => myhost.class.to_s}.merge!(options) unless myhost.nil?
    # self.vm_state.power_state == "on" ? options[:force_snapshot] = true : options[:force_snapshot] = false

    $log.info "MIQ(Vm-scan) NAME [#{options[:name]}] SCAN [#{options[:categories].inspect}] [#{options[:categories].class}]"

    begin
      inputs = {:vm => self, :host => self.host}
      MiqEvent.raise_evm_job_event(self, {:type => "scan", :prefix => "request"}, inputs)
    rescue => err
      $log.warn("MIQ(Vm-scan) NAME [#{options[:name]}] #{err.message}")
      return
    end

    begin
      self.last_scan_attempt_on = Time.now.utc
      self.save
      job = Job.create_job("VmScan", options)
      return job
    rescue => err
      $log.log_backtrace(err)
      raise
    end
  end

  # Call the miqhost webservice to do the SyncMetadata operation
  def sync_metadata(category, options = {})
    $log.debug "MIQ(#{self.class.name}#sync_metadata) category=[#{category}] [#{category.class}]"
    options = {
      "category" => category.join(","),
      "from_time" => self.last_drift_state_timestamp.try(:to_i),
      "taskid" => nil,
      "vm_id" => self.id
    }.merge(options)
    host = options.delete("host")
    options = {"args" => [self.path], "method_name" => "SyncMetadata", "vm_guid" => self.guid}.merge(options)
    ost = OpenStruct.new(options)
    host.call_ws(ost)
  rescue => err
    $log.log_backtrace(err)
  end

  # Call the miqhost webservice to do the ScanMetadata operation
  def scan_metadata(category, options = {})
    $log.info "MIQ(#{self.class.name}#scan_metadata) category=[#{category}] [#{category.class}]"
    options = {
      "category" => category.join(","),
      "taskid" => nil,
      "vm_id" => self.id
    }.merge(options)
    host = options.delete("host")
    # If the options hash has an "args" element, remove it and add it to the "args" element with self.path
    miqhost_args = Array(options.delete("args"))
    options = {"args" => [self.path] + miqhost_args, "method_name" => "ScanMetadata", "vm_guid" => self.guid}.merge(options)
    ost = OpenStruct.new(options)
    host.call_ws(ost)
  rescue => err
    $log.log_backtrace(err)
  end

  def scan_profile_list
    ScanItem.get_default_profiles
  end

  def scan_profile_categories(scan_profiles)
    cat_scan_list = []
    begin
      # Loop over all profiles and add category scan items to the array
      scan_profiles.to_miq_a.each do |p|
        p["definition"].each do |d|
          if d["item_type"] == "category"
            d["definition"]["content"].to_miq_a.each {|item| cat_scan_list << item["target"]}
          else
            cat_scan_list |= ["profiles"]
          end
        end
      end
    rescue
    end

    # If we get through the profile check and do not have anything pass the default list

    cat_scan_list.uniq!
    cat_scan_list = self.class.default_scan_categories_no_profile if cat_scan_list.empty?
    return cat_scan_list
  end

  def scan_on_registered_host_only?
    false
  end

  # TODO: Vmware specfic
  def require_snapshot_for_scan?
    return false unless self.runnable?
    return false if ['RedHat'].include?(self.vendor)
    return false if self.host && self.host.platform == "windows"
    return true
  end

  def scan_via_miq_vm(miqVm, ost)
    log_pref = "#{self.class.name}##{__method__}"

    $log.debug "#{log_pref}: Checking for file systems..."
    if miqVm.vmRootTrees[0].nil?
      raise MiqException::MiqVmMountError, "No root filesystem found." if miqVm.diskInitErrors.empty?

      err_msg = ''
      miqVm.diskInitErrors.each do |disk, err|
        err = "#{err} - #{disk}" unless err.include?(disk)
        err_msg += "#{err}\n"
      end
      raise err_msg.chomp
    end

    # Initialize stat collection variables
    ost.scanTime = Time.now.utc unless ost.scanTime
    status = "OK"; statusCode = 0; scanMessage = "OK"
    categoriesProcessed = 0
    ost.xml_class = XmlHash::Document
    driver = MiqservicesClientInternal.new

    UpdateAgentState(driver, ost, "Scanning", "Initializing scan")
    vmName, bb, vmId, lastErr, vmCfg = nil
    xml_summary = ost.xml_class.createDoc(:summary)
    xmlNode = xmlNodeScan = xml_summary.root.add_element("scanmetadata")
    xmlNodeScan.add_attributes("start_time" => ost.scanTime.iso8601)
    xml_summary.root.add_attributes("taskid" => ost.taskid)

    data_dir = File.join(File.expand_path(Rails.root), "data/metadata")
    begin
      Dir.mkdir(data_dir)
    rescue Errno::EEXIST
      # Ignore if the directory was created by another thread.
    end unless File.exist?(data_dir)
    ost.skipConfig = true
    ost.config = OpenStruct.new(
      :dataDir => data_dir,
      :forceFleeceDefault => false
    )

    begin
      bb = Manageiq::BlackBox.new(self.guid, ost)

      # categories = miqVm.miq_extract.categories
      categories = ost.category.split(',') # TODO: XXX Use scan profiles
      $log.debug "#{log_pref}: categories = [ #{categories.join(', ')} ]"

      categories.each do |c|
        UpdateAgentState(driver, ost, "Scanning", "Scanning #{c}")
        $log.info "#{log_pref}: Scanning [#{c}] information.  TaskId:[#{ost.taskid}]  VM:[#{vmName}]"
        st = Time.now
        xml = miqVm.extract(c)
        categoriesProcessed += 1
        $log.info "#{log_pref}: Scanning [#{c}] information ran for [#{Time.now - st}] seconds.  TaskId:[#{ost.taskid}]  VM:[#{vmName}]"
        if xml
          xml.root.add_attributes({"created_on" => ost.scanTime.to_i, "display_time" => ost.scanTime.iso8601})
          $log.debug "#{log_pref}: Writing scanned data to XML for [#{c}] to blackbox."
          bb.saveXmlData(xml, c)
          $log.debug "#{log_pref}: writing xml complete."

          categoryNode = xml_summary.class.load(xml.root.shallow_copy.to_xml.to_s).root
          categoryNode.add_attributes("start_time" => st.utc.iso8601, "end_time" => Time.now.utc.iso8601)
          xmlNode << categoryNode
        else
          # Handle categories that we do not expect to return data.
          # Otherwise, log an error if we do not get data back.
          unless c == "vmevents"
            $log.error "#{log_pref} Error: No XML returned for category [#{c}]  TaskId:[#{ost.taskid}]  VM:[#{vmName}]"
          end
        end
      end
    rescue NoMethodError => scanErr
      lastErr = scanErr
      $log.error "#{log_pref}: Scanmetadata Error - [#{scanErr}]"
      $log.error "#{log_pref}: Scanmetadata Error - [#{scanErr.backtrace.join("\n")}]"
    rescue Timeout::Error, StandardError => scanErr
      lastErr = scanErr
    ensure
      bb.close if bb
      UpdateAgentState(driver, ost, "Scanning", "Scanning completed.")

      # If we are sent a TaskId transfer a end of job summary xml.
      $log.info "#{log_pref} Starting: Sending scan summary to server.  TaskId:[#{ost.taskid}]  VM:[#{vmName}]"
      if lastErr
        status = "Error"
        statusCode = 8
        statusCode = 16 if categoriesProcessed.zero?
        scanMessage = lastErr.to_s
        $log.error "#{log_pref} ScanMetadata error status:[#{statusCode}]:  message:[#{lastErr}]"
        lastErr.backtrace.each {|m| $log.debug m} if $log.debug?
      end

      xmlNodeScan.add_attributes("end_time" => Time.now.utc.iso8601, "status" => status, "status_code" => statusCode.to_s, "message" => scanMessage)
      driver.SaveVmmetadata(vmId, xml_summary.to_xml.miqEncode, "b64,zlib,xml", ost.taskid)
      $log.info "#{log_pref} Completed: Sending scan summary to server.  TaskId:[#{ost.taskid}]  VM:[#{vmName}]"
    end
  end

  def sync_stashed_metadata(ost)
    log_pref = "#{self.class.name}##{__method__}"

    $log.info "MIQ(#{log_pref}) from #{self.class.name}"
    xml_summary = nil
    begin
      raise "No synchronize category specified" if ost.category.nil?
      categories = ost.category.split(",")
      ost.scanTime = Time.now.utc
      ost.compress = true       # Request that data returned from the blackbox is compressed
      ost.xml_class = REXML::Document
      # TODO: XXX if from_time is not a string (see sync_metadata() above), loadXmlData fails.
      # Just clear it for now, until we figure out the right thing to do.
      ost.from_time = nil

      vmName, bb, vmId = nil
      driver = MiqservicesClientInternal.new
      xml_summary = ost.xml_class.createDoc("<summary/>")
      $log.debug "#{log_pref}: xml_summary1 = #{xml_summary.class.name}"
      xmlNode = xml_summary.root.add_element("syncmetadata")
      xml_summary.root.add_attributes("scan_time" => ost.scanTime, "taskid" => ost.taskid)
      ost.skipConfig = true
      data_dir = File.join(File.expand_path(Rails.root), "data/metadata")
      ost.config = OpenStruct.new(
        :dataDir => data_dir,
        :forceFleeceDefault => false
      )
      vmName = self.name
      bb = Manageiq::BlackBox.new(self.guid, ost)

      UpdateAgentState(driver, ost, "Synchronize", "Synchronization in progress")
      categories.each do |c|
        c.gsub!("\"","")
        c.strip!

        # Grab data out of the bb.  (results may be limited by parms in ost like "from_time")
        ret = bb.loadXmlData(c, ost)

        xmlNode << ost.xml_class.load(ret.xml.root.shallow_copy.to_xml.to_s).root
        items_total     = ret.xml.root.attributes["items_total"].to_i
        items_selected  = ret.xml.root.attributes["items_selected"].to_i
        data = ret.xml.miqEncode

        # Verify that we have data to send
        unless items_selected.zero?
          $log.info "#{log_pref} Starting:  Sending vm data for [#{c}] to server.  Size:[#{data.length}]  TaskId:[#{ost.taskid}]  VM:[#{vmName}]"
          driver.SaveVmmetadata(bb.vmId, data, "b64,zlib,xml", ost.taskid)
          $log.info "Completed: Sending vm data for [#{c}] to server.  Size:[#{data.length}]  TaskId:[#{ost.taskid}]  VM:[#{vmName}]"
        else
          # Do not send empty XMLs.  Warn if there is not data at all, or just not items selected.
          if items_total.zero?
            $log.warn "#{log_pref} Synchronize: No data found for [#{c}].  Items:Total[#{items_total}] Selected[#{items_selected}]  TaskId:[#{ost.taskid}]  VM:[#{vmName}]"
          else
            $log.warn "#{log_pref} Synchronize: No data selected for [#{c}].  Items:Total[#{items_total}] Selected[#{items_selected}]  TaskId:[#{ost.taskid}]  VM:[#{vmName}]"
          end
        end
      end
    rescue => syncErr
      $log.error "#{log_pref}: #{syncErr}"
      $log.debug syncErr.backtrace.join("\n")
    ensure
      if bb
        bb.postSync()
        bb.close
      end
      
      $log.info "#{log_pref} Starting:  Sending vm summary to server.  TaskId:[#{ost.taskid}]  VM:[#{vmName}]"
      $log.debug "#{log_pref}: xml_summary2 = #{xml_summary.class.name}"
      driver.SaveVmmetadata(vmId, xml_summary.miqEncode, "b64,zlib,xml", ost.taskid)
      $log.info "#{log_pref} Completed: Sending vm summary to server.  TaskId:[#{ost.taskid}]  VM:[#{vmName}]"
      
      UpdateAgentState(driver, ost, "Synchronize", "Synchronization complete")

      raise syncErr if syncErr
    end
    ost.value = "OK\n"
  end

  def UpdateAgentState(driver, ost, state, message)
    ost.agent_state = state
    ost.agent_message = message
    driver.AgentJobState(ost.taskid, ost.agent_state, ost.agent_message) if ost.taskid && ost.taskid.empty? == false
  end

end
