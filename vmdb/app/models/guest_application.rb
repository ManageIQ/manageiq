class GuestApplication < ActiveRecord::Base
  belongs_to :vm_or_template
  belongs_to :host

  include ReportableMixin

  virtual_column :v_unique_name, :type => :string

  def self.add_elements(parent, xmlNode)
    add_missing_elements(parent, xmlNode, "software/applications")
  end

  def self.add_missing_elements(parent, xmlNode, findPath)
    hashes = xml_to_hashes(xmlNode, findPath)
    return if hashes.nil?
    EmsRefresh.save_guest_applications_inventory(parent, hashes)
  end

  def self.xml_to_hashes(xmlNode, findPath)
    el = XmlFind.findElement(findPath, xmlNode.root)
    return nil unless MiqXml.isXmlElement?(el)

    result = []
    el.each_element { |e| result << e.attributes.to_h }
    result
  end

  def v_unique_name
    return self.name if self.arch.blank? || self.arch == "noarch"
    return "#{self.name} (#{self.arch})"
  end
end
