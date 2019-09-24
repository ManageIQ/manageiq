class FirewallRule < ApplicationRecord
  belongs_to :resource, :polymorphic => true
  belongs_to :source_security_group, :class_name => "SecurityGroup"

  def operating_system
    resource.kind_of?(OperatingSystem) ? resource : nil
  end

  def operating_system=(os)
    raise ArgumentError, _("must be an OperatingSystem") unless os.kind_of?(OperatingSystem)
    self.resource = os
  end

  def port_range
    port..(end_port || port)
  end

  def self.add_elements(target, xmlNode)
    add_missing_elements(target, xmlNode, nil)
  end

  def self.add_missing_elements(parent, xmlNode, findPath)
    return if parent.operating_system.nil?

    hashes = xml_to_hashes(xmlNode, findPath)
    EmsRefresh.save_firewall_rules_inventory(parent.operating_system, hashes, :scan) if hashes
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
