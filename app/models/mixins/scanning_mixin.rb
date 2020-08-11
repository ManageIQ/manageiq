# TODO: Nothing appears to be using xml_utils in this file???
# Perhaps, it's being required here because lower level code requires xml_utils to be loaded
# but wrongly doesn't require it itself.
require 'xml/xml_utils'

require 'scanning_operations_mixin'

module ScanningMixin
  extend ActiveSupport::Concern
  include ScanningOperationsMixin

  module ClassMethods
    def default_scan_categories_no_profile
      default_scan_categories - ["profiles"]
    end

    def default_scan_categories
      %w(vmconfig accounts software services system profiles)
    end

    # Stash metadata before sync.
    # Called from Queue
    def save_metadata(target_id, data_array)
      xml_file, data_type = Marshal.load(data_array)
      target = base_class.find_by(:id => target_id)
      xml_file = MIQEncode.decode(xml_file) if data_type.include?('b64,zlib')
      begin
        doc = MiqXml.load(xml_file)
      rescue REXML::ParseException
        n = MiqXml.load(xml_file, :nokogiri)
        xml_file = n.to_s
        doc = MiqXml.load(xml_file)
      end

      taskid = doc.root.attributes["taskid"]
      _log.info("TaskId = [#{taskid}]")
      unless taskid.blank?
        name =  begin
                  File.basename(doc.root.elements[1].elements[1].attributes["original_filename"], ".*")
                rescue
                  "vmscan"
                end
        job = Job.find_by(:guid => taskid)
        raise _("Unable to process data for job with id <%{number}>. Job not found.") % {:number => taskid} if job.nil?
        begin
          job.signal(:data, xml_file)
        rescue => err
          _log.error("Processing xml for [#{name}] [#{err}]")
          _log.log_backtrace(err)
        end
      end

      case doc.root.name.downcase
      when "summary"
        _log.info("Summary XML received. [#{doc.root.to_s[0..100]}]")
      when "vmmetadata" # TODO: - should be "metadata"
        # doc being sent up has a some extra header elements we need to remove (<vmmetadata>, and <item>)
        begin
          # Reset the root of the xml document to match the expected starting point
          doc.root = doc.root.elements[1].elements[1]
        rescue => err
          _log.error("Invalid xml error [#{err}] for xml:[#{doc}]")
        end
        target.add_elements(doc)
        target.save!
      when "vmevents" # TODO: - should be "events"
        target.add_elements(doc)
        target.save!
      else
        target.add_elements(doc)
        target.save!
      end
    end
  end # ClassMethods

  # Process XML documents from VM scans
  def add_elements(xml_node)
    return if xml_node.nil?
    _log.info("Adding XML elements for [#{id}] from [#{xml_node.root.name}]")
    updated = false

    # Find out what XML file document we are being passed.
    case xml_node.root.name
    when "miq"
      for element_class in [OperatingSystem, Account, SystemService, GuestApplication, Patch, Network]
        begin
          element_class.add_elements(self, xml_node)
          updated = true
        rescue Exception => err
          _log.log_backtrace(err)
        end
      end
    when "scan_profiles"
      ScanItem.add_elements(self, xml_node)
      updated = true
    when "vm_configuration" # TODO: should be "configuration"?
      Hardware.add_elements(self, xml_node)
      updated = true
    when "vmevents" # TODO: should be "events"?
      # Record vm operational and configuration events
      MiqEvent.add_elements(self, xml_node)
    end
    # Update the last sync time if we did something
    self.last_sync_on = Time.at(xml_node.root.attributes["created_on"].to_i).utc if updated == true && xml_node.root.attributes["created_on"]
    save
    hardware.save if self.respond_to?(:hardware) && !hardware.nil?
  end

  def scan_queue(userid = "system", options = {})
    MiqQueue.submit_job(
      :class_name  => self.class.base_class.name,
      :instance_id => id,
      :method_name => "scan",
      :args        => [userid, options]
    )
  end

  # Do the SyncMetadata operation through the server smart proxy
  def sync_metadata(category, options = {})
    _log.debug("category=[#{category}] [#{category.class}]")
    options = {
      "category"    => category.join(","),
      "from_time"   => nil, # TODO: is this still needed?: last_drift_state_timestamp.try(:to_i),
      "taskid"      => nil,
      "target_id"   => id,
      "target_type" => self.class.base_class.name
    }.merge(options)
    host = options.delete("host")
    options = {
      "args"        => [path_arg],
      "method_name" => "sync_metadata",
      "vm_guid"     => guid # TODO: target_guid
    }.merge(options)
    ost = OpenStruct.new(options)
    host.queue_call(ost)
  rescue => err
    _log.log_backtrace(err)
  end

  # Do the ScanMetadata operation through the server smart proxy
  def scan_metadata(category, options = {})
    _log.info("category=[#{category}] [#{category.class}]")
    options = {
      "category"    => category.join(","),
      "taskid"      => nil,
      "target_id"   => id,
      "target_type" => self.class.base_class.name
    }.merge(options)
    host = options.delete("host")
    # If the options hash has an "args" element, remove it and add it to the "args" element with self.path
    miqhost_args = Array(options.delete("args"))
    options = {
      "args"        => [path_arg] + miqhost_args,
      "method_name" => "scan_metadata",
      "vm_guid"     => guid # TODO: target_guid
    }.merge(options)
    ost = OpenStruct.new(options)
    host.queue_call(ost)
  rescue => err
    _log.log_backtrace(err)
  end

  def path_arg
    return path if self.respond_to?(:path)
    return name if self.respond_to?(:name)
    nil
  end
  private :path_arg

  def scan_profile_list
    ScanItem.get_default_profiles
  end

  def scan_profile_categories(scan_profiles)
    cat_scan_list = []
    begin
      # Loop over all profiles and add category scan items to the array
      Array.wrap(scan_profiles).each do |p|
        p["definition"].each do |d|
          if d["item_type"] == "category"
            Array.wrap(d["definition"]["content"]).each { |item| cat_scan_list << item["target"] }
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
    cat_scan_list
  end

  def scan_on_registered_host_only?
    false
  end

  def scan_via_miq_vm(miqVm, ost)
    # Initialize stat collection variables
    ost.scanTime = Time.now.utc unless ost.scanTime
    status               = "OK"
    status_code          = 0
    scan_message         = "OK"
    categories_processed = 0
    ost.xml_class = XmlHash::Document

    _log.debug("Scanning - Initializing scan")
    update_job_message(ost, "Initializing scan")
    bb, last_err = nil
    xml_summary = ost.xml_class.createDoc(:summary)
    xml_node = xml_node_scan = xml_summary.root.add_element("scanmetadata")
    xml_node_scan.add_attributes("start_time" => ost.scanTime.iso8601)
    xml_summary.root.add_attributes("taskid" => ost.taskid)

    data_dir = File.join(File.expand_path(Rails.root), "data/metadata")
    _log.debug("creating #{data_dir}")
    begin
      Dir.mkdir(data_dir)
    rescue Errno::EEXIST
      # Ignore if the directory was created by another thread.
    end unless File.exist?(data_dir)
    ost.skipConfig = true
    ost.config = OpenStruct.new(
      :dataDir            => data_dir,
      :forceFleeceDefault => false
    )

    begin
      require 'metadata/MIQExtract/MIQExtract'
      _log.debug("instantiating MIQExtract")
      extractor = MIQExtract.new(miqVm, ost)
      _log.debug("instantiated MIQExtract")

      require 'blackbox/VmBlackBox'
      _log.debug("instantiating BlackBox")
      bb = Manageiq::BlackBox.new(guid, ost) # TODO: target must have GUID
      _log.debug("instantiated BlackBox")

      _log.debug("Checking for file systems...")
      raise extractor.systemFsMsg unless extractor.systemFs

      categories = extractor.categories
      _log.debug("categories = [ #{categories.join(', ')} ]")

      categories.each do |c|
        update_job_message(ost, "Scanning #{c}")
        _log.info("Scanning [#{c}] information.  TaskId:[#{ost.taskid}]  VM:[#{name}]")
        st = Time.now
        xml = extractor.extract(c) { |scan_data| update_job_message(ost, scan_data[:msg]) }
        categories_processed += 1
        _log.info("Scanning [#{c}] information ran for [#{Time.now - st}] seconds.  TaskId:[#{ost.taskid}]  VM:[#{name}]")
        if xml
          xml.root.add_attributes("created_on" => ost.scanTime.to_i, "display_time" => ost.scanTime.iso8601)
          _log.debug("Writing scanned data to XML for [#{c}] to blackbox.")
          bb.saveXmlData(xml, c)
          _log.debug("writing xml complete.")

          category_node = xml_summary.class.load(xml.root.shallow_copy.to_xml.to_s).root
          category_node.add_attributes("start_time" => st.utc.iso8601, "end_time" => Time.now.utc.iso8601)
          xml_node << category_node
        else
          # Handle categories that we do not expect to return data.
          # Otherwise, log an error if we do not get data back.
          unless c == "vmevents"
            _log.error("Error: No XML returned for category [#{c}]  TaskId:[#{ost.taskid}]  VM:[#{name}]")
          end
        end
      end
    rescue NoMethodError => scanErr
      last_err = scanErr
      _log.error("Scanmetadata Error - [#{scanErr}]")
      _log.log_backtrace(scanErr)
    rescue Timeout::Error, StandardError => scanErr
      last_err = scanErr
    ensure
      bb.close if bb
      update_job_message(ost, "Scanning completed.")

      # If we are sent a TaskId transfer a end of job summary xml.
      _log.info("Starting: Sending scan summary to server.  TaskId:[#{ost.taskid}]  VM:[#{name}]")
      if last_err
        status = "Error"
        status_code = 8
        status_code = 16 if categories_processed.zero?
        scan_message = last_err.to_s
        _log.error("ScanMetadata error status:[#{status_code}]:  message:[#{last_err}]")
        _log.log_backtrace(last_err, :debug)
      end

      xml_node_scan.add_attributes(
        "end_time"    => Time.now.utc.iso8601,
        "status"      => status,
        "status_code" => status_code.to_s,
        "message"     => scan_message
      )
      save_metadata_op(MIQEncode.encode(xml_summary.to_xml.to_s), "b64,zlib,xml", ost.taskid)
      _log.info("Completed: Sending scan summary to server.  TaskId:[#{ost.taskid}]  target:[#{name}]")
    end
  end

  def sync_stashed_metadata(ost)
    _log.info("from #{self.class.name}")
    xml_summary = nil
    begin
      raise _("No synchronize category specified") if ost.category.nil?
      categories = ost.category.split(",")
      ost.scanTime = Time.now.utc
      ost.compress = true       # Request that data returned from the blackbox is compressed
      ost.xml_class = REXML::Document
      # TODO: if from_time is not a string (see sync_metadata() above), loadXmlData fails.
      # Just clear it for now, until we figure out the right thing to do.
      ost.from_time = nil

      bb = nil
      xml_summary = ost.xml_class.createDoc("<summary/>")
      _log.debug("xml_summary1 = #{xml_summary.class.name}")
      xml_node = xml_summary.root.add_element("syncmetadata")
      xml_summary.root.add_attributes("scan_time" => ost.scanTime, "taskid" => ost.taskid)
      ost.skipConfig = true
      data_dir = File.join(File.expand_path(Rails.root), "data/metadata")
      ost.config = OpenStruct.new(
        :dataDir            => data_dir,
        :forceFleeceDefault => false
      )
      require 'blackbox/VmBlackBox'
      bb = Manageiq::BlackBox.new(guid, ost)

      update_job_message(ost, "Synchronization in progress")
      categories.each do |c|
        c.delete!("\"")
        c.strip!

        # Grab data out of the bb.  (results may be limited by parms in ost like "from_time")
        ret = bb.loadXmlData(c, ost)

        xml_node << ost.xml_class.load(ret.xml.root.shallow_copy.to_xml.to_s).root
        items_total     = ret.xml.root.attributes["items_total"].to_i
        items_selected  = ret.xml.root.attributes["items_selected"].to_i
        data = MIQEncode.encode(ret.xml.to_s)

        # Verify that we have data to send
        if !items_selected.zero?
          _log.info("Starting:  Sending target data for [#{c}] to server.  Size:[#{data.length}]  TaskId:[#{ost.taskid}]  target:[#{name}]")
          save_metadata_op(data, "b64,zlib,xml", ost.taskid)
          _log.info("Completed: Sending target data for [#{c}] to server.  Size:[#{data.length}]  TaskId:[#{ost.taskid}]  target:[#{name}]")
        else
          # Do not send empty XMLs.  Warn if there is not data at all, or just not items selected.
          if items_total.zero?
            _log.warn("Synchronize: No data found for [#{c}].  Items:Total[#{items_total}] Selected[#{items_selected}]  TaskId:[#{ost.taskid}]  VM:[#{name}]")
          else
            _log.warn("Synchronize: No data selected for [#{c}].  Items:Total[#{items_total}] Selected[#{items_selected}]  TaskId:[#{ost.taskid}]  VM:[#{name}]")
          end
        end
      end
    rescue => syncErr
      _log.error(syncErr.to_s)
      _log.log_backtrace(syncErr, :debug)
    ensure
      if bb
        bb.postSync
        bb.close
      end

      _log.info("Starting:  Sending target summary to server.  TaskId:[#{ost.taskid}]  target:[#{name}]")
      _log.debug("xml_summary2 = #{xml_summary.class.name}")
      save_metadata_op(MIQEncode.encode(xml_summary.to_s), "b64,zlib,xml", ost.taskid)
      _log.info("Completed: Sending target summary to server.  TaskId:[#{ost.taskid}]  target:[#{name}]")

      update_job_message(ost, "Synchronization complete")

      raise syncErr if syncErr
    end
    ost.value = "OK\n"
  end

  def update_job_message(ost, message)
    ost.message = message
    if ost.taskid.present?
      MiqQueue.submit_job(
        :service     => "smartstate",
        :class_name  => "Job",
        :method_name => "update_message",
        :args        => [ost.taskid, message],
        :task_id     => "job_message_#{Time.now.to_i}",
      )
    end
  end
end
