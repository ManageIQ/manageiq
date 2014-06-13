class OsProcess < ActiveRecord::Base
  belongs_to :operating_system

  include ReportableMixin

  def self.add_elements(vm, xmlNode)
    add_missing_elements(vm, xmlNode, nil)
  end

  def self.add_missing_elements(parent, xmlNode, findPath)
    return if parent.operating_system.nil?

    hashes = xml_to_hashes(xmlNode, findPath)
    return if hashes.nil?
    EmsRefresh.save_os_processes_inventory(parent.operating_system, hashes)
  end

  def self.xml_to_hashes(xmlNode, findPath)
    result = []
    if xmlNode.kind_of?(Hash)
      xmlNode.each_pair {|k,v| result << v}
    else
      el = XmlFind.findElement(findPath, xmlNode.root)
      return nil unless MiqXml.isXmlElement?(el)

      el.each_element { |e| result << e.attributes.to_h }
    end
    return result
  end
end
