class AdvancedSetting < ApplicationRecord
  belongs_to :resource, :polymorphic => true

  def self.add_elements(parent, xml_node)
    add_missing_elements(parent, xml_node, nil)
  end

  def self.add_missing_elements(parent, xml_node, find_path)
    hashes = xml_to_hashes(xml_node, find_path)
    EmsRefresh.save_advanced_settings_inventory(parent, hashes) if hashes
  end

  def self.xml_to_hashes(xml_node, find_path)
    result = []
    if xml_node.kind_of?(Array)
      return xml_node
    else
      el = XmlFind.findElement(find_path, xml_node.root)
      return nil unless MiqXml.isXmlElement?(el)

      el.each_element { |e| result << e.attributes.to_h }
    end
    result
  end
end
