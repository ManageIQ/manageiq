class GuestApplication < ApplicationRecord
  belongs_to :vm_or_template
  belongs_to :vm, :foreign_key => :vm_or_template_id
  belongs_to :host
  belongs_to :container_image

  virtual_column :v_unique_name, :type => :string

  def self.add_elements(parent, xmlNode)
    add_missing_elements(parent, xmlNode, "software/applications")
  end

  def self.add_missing_elements(parent, xmlNode, findPath)
    hashes = xml_to_hashes(xmlNode, findPath)
    EmsRefresh.save_guest_applications_inventory(parent, hashes) if hashes
  end

  def self.xml_to_hashes(xmlNode, findPath)
    el = XmlFind.findElement(findPath, xmlNode.root)
    return nil unless MiqXml.isXmlElement?(el)

    result = []
    el.each_element { |e| result << e.attributes.to_h }
    result
  end

  def v_unique_name
    return name if arch.blank? || arch == "noarch"
    "#{name} (#{arch})"
  end
end
