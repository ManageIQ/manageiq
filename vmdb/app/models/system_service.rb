class SystemService < ActiveRecord::Base
  belongs_to :vm_or_template
  belongs_to :vm,           :foreign_key => :vm_or_template_id
  belongs_to :miq_template, :foreign_key => :vm_or_template_id
  belongs_to :host

  include ReportableMixin

  SVC_TYPES = {
    # Type     Display
    ""    =>    "",
    "1"   =>    "Kernel Driver",
    "2"   =>    "File System Driver",
    "4"   =>    "Service Adapter",
    "8"   =>    "Recognizer Driver",
    "16"  =>    "Win32 Own Process",
    "32"  =>    "Win32 Shared Process",
    "256" =>    "Interactive",
    "272" =>    "Win32 Own Process, Interactive",
    "288" =>    "Win32 Shared Process, Interactive",
  }

  START_TYPES = {
    # Type     Display
    ""  =>    "",
    "0" =>    "Boot Start",
    "1" =>    "System Start",
    "2" =>    "Automatic",
    "3" =>    "Manual",
    "4" =>    "Disabled"
  }

  def self.add_elements(parent, xmlNode)
    add_missing_elements(parent, xmlNode, "services")
  end

  def self.add_missing_elements(parent, xmlNode, findPath)
    hashes = xml_to_hashes(xmlNode, findPath)
    EmsRefresh.save_system_services_inventory(parent, hashes, :scan) if hashes
  end

  def self.xml_to_hashes(xmlNode, findPath, typeName=nil)
    el = XmlFind.findElement(findPath, xmlNode.root)
    return nil unless MiqXml.isXmlElement?(el)

    result = []
    el.each_element do |e|
      nh = e.attributes.to_h
      next unless typeName.nil? || nh[:typename] == typeName

      e.each_element do |e2|
        case e2.name
        when "depend_on_service"
          nh[:depend_on_service] = ( nh[:depend_on_service].nil? ? e2.attributes[:name] : nh[:depend_on_service] + " " + e2.attributes[:name] )
        when "depend_on_group"
          nh[:depend_on_group] = ( nh[:depend_on_group].nil? ? e2.attributes[:name] : nh[:depend_on_group] + " " + e2.attributes[:name] )
        when "enable_run_level"
          nh[:enable_run_levels] = ( nh[:enable_run_levels].nil? ? e2.attributes[:value] : nh[:enable_run_levels] + e2.attributes[:value] )
        when "disable_run_level"
          nh[:disable_run_levels] = ( nh[:disable_run_levels].nil? ? e2.attributes[:value] : nh[:disable_run_levels] + e2.attributes[:value] )
        end
      end

      result << nh
    end
    result
  end

  def self.friendly(data)
    #Convert service start and svc_type fields to friendly values.
    return if data == nil

    isarray = data.is_a?(Array)
    data = [data] unless isarray
    data.each {|s| s.start = START_TYPES[s.start] if s.attribute_names.include?("start") &&
      START_TYPES.include?(s.start)}
    data.each {|s| s.svc_type = SVC_TYPES[s.svc_type] if s.attribute_names.include?("svc_type") &&
      SVC_TYPES.include?(s.svc_type)}
    isarray ? data : data[0]
  end

  def self.find(*args)
    #Redefind find method to allow for friendly name conversion of results.
    data = super
    friendly(data)
  end

  def self.method_missing(*args)
    #Handle friendly name conversion for dynamic find methods.
    data = super
    friendly(data)
  end
end
