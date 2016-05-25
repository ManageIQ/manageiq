class Network < ApplicationRecord
  belongs_to :hardware
  belongs_to :guest_device, :foreign_key => "device_id", :inverse_of => :network

  def self.add_elements(vm, xmlNode)
    add_missing_elements(vm, xmlNode, "system/networks")
  end

  def self.add_missing_elements(parent, xmlNode, findPath)
    return if parent.nil?

    hashes = xml_to_hashes(xmlNode, findPath)
    return if hashes.nil?

    if parent.respond_to?(:hardware)
      # it's possible that the hardware for this vm does not exist, so create it
      parent.hardware = Hardware.new if parent.hardware.nil?

      EmsRefresh.save_networks_inventory(parent.hardware, hashes, :scan)
    end
  end

  def self.xml_to_hashes(xmlNode, findPath)
    el = XmlFind.findElement(findPath, xmlNode.root)
    return nil unless MiqXml.isXmlElement?(el)

    result = []
    el.each_element { |e| result << e.attributes.to_h }
    result
  end
end
