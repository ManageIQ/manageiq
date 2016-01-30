class AdvancedSetting < ApplicationRecord
  belongs_to :resource, :polymorphic => true

  include ReportableMixin

  def self.add_elements(parent, xmlNode)
    add_missing_elements(parent, xmlNode, nil)
  end

  def self.add_missing_elements(parent, xmlNode, findPath)
    hashes = xml_to_hashes(xmlNode, findPath)
    EmsRefresh.save_advanced_settings_inventory(parent, hashes) if hashes
  end

  def self.xml_to_hashes(xmlNode, findPath)
    result = []
    if xmlNode.kind_of?(Array)
      return xmlNode
    else
      el = XmlFind.findElement(findPath, xmlNode.root)
      return nil unless MiqXml.isXmlElement?(el)

      el.each_element { |e| result << e.attributes.to_h }
    end
    result
  end
end
