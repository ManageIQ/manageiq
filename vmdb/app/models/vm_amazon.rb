class VmAmazon < VmCloud
  include_concern 'Operations'

  def provider_object(connection = nil)
    connection ||= self.ext_management_system.connect
    connection.instances[self.ems_ref]
  end

  #
  # Relationship methods
  #

  def disconnect_inv
    super

    # Mark all instances no longer found as terminated
    self.power_state == "off"
    self.save
  end

  def proxies4job(job=nil)
    {
      :proxies => [MiqServer.my_server],
      :message => 'Perform SmartState Analysis on this VM'
    }
  end

  def disconnected
    false
  end

  def disconnected?
    false
  end

  # TODO: XXX Common for Amazon VMs and templates?
  # Move to amazon_scanning module or to an amazon_vm_or_template superclass?
  def perform_metadata_scan(ost)
    self.ext_management_system.request_metadata_scan(self.ems_ref, ost)
  end

  def perform_metadata_sync(ost)
    categories = ost.category.split(',')
    #
    # TODO: XXX Temp code to be replaced with SQS queue retrieval code (Ec2ExtractQueue).
    # Should queue retrieval code, in separate worker, stash metadata in the BlackBox?
    # Then this method can just use sync_stashed_metadata() from scanning.rb
    #
    require 'Amazon/MiqEc2'
    user, pwd = v.ext_management_system.auth_user_pwd
    begin
      results = MiqEc2.retrieve_scan_metadata(user, pwd, v.location, categories)
      raise "Scan metadata not found." if results.nil?
    rescue => err
      Job.find_by_guid(ost.taskid).signal(:abort, err.message, "error")
      return
    end

    xml_summary = MiqXml.createDoc("<summary/>")
    xmlNode = xml_summary.root.add_element("syncmetadata")
    xml_summary.root.add_attributes({"scan_time"=>Time.now.to_s, "taskid"=>ost.taskid})

    results.each do |r|
      c = categories.shift
      next if r.nil?
      wrap_doc = <<-EOL
        <vmmetadata created_on='#{Time.now.to_i}' taskid='#{ost.taskid}'
          version='2.0' from_time='' last_scan='#{Time.now.to_i}'
          items_selected='1' items_total='1' original_filename='#{c}'>
          <item scanType='full' />
        </vmmetadata>
      EOL
      doc = MiqXml.load(wrap_doc)
      data = MiqXml.load(r)
      doc.root.elements[1] << data.root

      xmlNode << MiqXml.load(doc.root.shallow_copy.to_s).root

      MiqQueue.put(:target_id => v.id, :class_name => "Vm", :method_name => "save_metadata", :data => Marshal.dump([doc.miqEncode, "b64,zlib,xml"]), :task_id => ost.taskid, :zone => v.my_zone, :role => "smartstate")
    end

    MiqQueue.put(:target_id => v.id, :class_name => "Vm", :method_name => "save_metadata", :data => Marshal.dump([xml_summary.miqEncode, "b64,zlib,xml"]), :task_id => ost.taskid, :zone => v.my_zone, :role => "smartstate")
  end

  #
  # EC2 interactions
  #

  def set_custom_field(attribute, value)
    with_provider_object { |ec2_instance| ec2_instance.tags[attribute] = value }
  end

end
